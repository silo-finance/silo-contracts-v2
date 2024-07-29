// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";

import {ISiloOracle} from "../interfaces/ISiloOracle.sol";
import {ISilo} from "../interfaces/ISilo.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";
import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";
import {SiloStdLib} from "./SiloStdLib.sol";
import {SiloMathLib} from "./SiloMathLib.sol";
import {Rounding} from "./Rounding.sol";
import {Hook} from "./Hook.sol";

library SiloLendingLib {
    using SafeERC20 for IERC20;
    using Math for uint256;

    uint256 internal constant _PRECISION_DECIMALS = 1e18;

    /// @notice Allows repaying borrowed assets either partially or in full
    /// @param _debtShareToken debt share token address
    /// @param _debtAsset underlaying debt asset address
    /// @param _assets The amount of assets to repay. Use 0 if shares are used.
    /// @param _shares The number of corresponding shares associated with the debt. Use 0 if assets are used.
    /// @param _borrower The account that has the debt
    /// @param _repayer The account that is repaying the debt
    /// @param _totalDebt The storage reference for the total amount of debt assets
    /// @return assets The amount of assets that was repaid
    /// @return shares The corresponding number of debt shares that were repaid
    function repay(
        IShareToken _debtShareToken,
        address _debtAsset,
        uint256 _assets,
        uint256 _shares,
        address _borrower,
        address _repayer,
        ISilo.Assets storage _totalDebt
    ) internal returns (uint256 assets, uint256 shares) {
        if (_assets == 0 && _shares == 0) revert ISilo.ZeroAssets();

        uint256 totalDebtAssets = _totalDebt.assets;

        (assets, shares) = SiloMathLib.convertToAssetsAndToShares(
            _assets,
            _shares,
            totalDebtAssets,
            _debtShareToken.totalSupply(),
            Rounding.REPAY_TO_ASSETS,
            Rounding.REPAY_TO_SHARES,
            ISilo.AssetType.Debt
        );

        if (shares == 0) revert ISilo.ZeroShares();

        // subtract repayment from debt
        _totalDebt.assets = totalDebtAssets - assets;

        // Anyone can repay anyone's debt so no approval check is needed. If hook receiver reenters then
        // no harm done because state changes are completed.
        _debtShareToken.burn(_borrower, _repayer, shares);
        // fee-on-transfer is ignored
        // Reentrancy is possible only for view methods (read-only reentrancy),
        // so no harm can be done as the state is already updated.
        // We do not expect the silo to work with any malicious token that will not send tokens back.
        IERC20(_debtAsset).safeTransferFrom(_repayer, address(this), assets);
    }

    /// @notice Accrues interest on assets, updating the collateral and debt balances
    /// @dev This method will accrue interest for ONE asset ONLY, to calculate for both silos you have to call it twice
    /// with `_configData` for each token
    /// @param _interestRateModel The address of the interest rate model to calculate the compound interest rate
    /// @param _daoFee DAO's fee in 18 decimals points
    /// @param _deployerFee Deployer's fee in 18 decimals points
    /// @param _siloData The storage reference for the silo's data storing earned fees and interest rate timestamp
    /// @param _totalCollateral The storage reference for the total collateral assets
    /// @param _totalDebt The storage reference for the total debt assets
    /// @return accruedInterest The total amount of interest accrued
    function accrueInterestForAsset(
        address _interestRateModel,
        uint256 _daoFee,
        uint256 _deployerFee,
        ISilo.SiloData storage _siloData,
        ISilo.Assets storage _totalCollateral,
        ISilo.Assets storage _totalDebt
    ) internal returns (uint256 accruedInterest) {
        uint64 lastTimestamp = _siloData.interestRateTimestamp;

        // This is the first time, so we can return early and save some gas
        if (lastTimestamp == 0) {
            _siloData.interestRateTimestamp = uint64(block.timestamp);
            return 0;
        }

        // Interest has already been accrued this block
        if (lastTimestamp == block.timestamp) {
            return 0;
        }

        uint256 totalFees;
        uint256 totalCollateralAssets = _totalCollateral.assets;
        uint256 totalDebtAssets = _totalDebt.assets;

        (
            _totalCollateral.assets, _totalDebt.assets, totalFees, accruedInterest
        ) = SiloMathLib.getCollateralAmountsWithInterest(
            totalCollateralAssets,
            totalDebtAssets,
            IInterestRateModel(_interestRateModel).getCompoundInterestRateAndUpdate(
                totalCollateralAssets,
                totalDebtAssets,
                lastTimestamp
            ),
            _daoFee,
            _deployerFee
        );

        // update remaining contract state
        _siloData.interestRateTimestamp = uint64(block.timestamp);

        // we operating on chunks (fees) of real tokens, so overflow should not happen
        // fee is simply to small to overflow on cast to uint192, even if, we will get lower fee
        unchecked { _siloData.daoAndDeployerFees += uint192(totalFees); }
    }

    /// @notice Allows a user or a delegate to borrow assets against their collateral
    /// @dev The function checks for necessary conditions such as borrow possibility, enough liquidity, and zero
    /// values
    /// @param _debtShareToken address of debt share token
    /// @param _token address of underlying debt token
    /// @param _spender Address which initiates the borrowing action on behalf of the borrower
    /// @param _totalCollateralAssets Current (with interest) total collateral assets
    /// @param _totalDebt Current total outstanding debt in the system
    /// @return borrowedAssets Actual number of assets that the user has borrowed
    /// @return borrowedShares Number of debt share tokens corresponding to the borrowed assets
    function borrow(
        address _debtShareToken,
        address _token,
        address _spender,
        ISilo.BorrowArgs memory _args,
        uint256 _totalCollateralAssets,
        ISilo.Assets storage _totalDebt
    )
        internal
        returns (uint256 borrowedAssets, uint256 borrowedShares)
    {
        if (_args.assets == 0 && _args.shares == 0) revert ISilo.ZeroAssets();

        uint256 totalDebtAssets = _totalDebt.assets;

        (borrowedAssets, borrowedShares) = SiloMathLib.convertToAssetsAndToShares(
            _args.assets,
            _args.shares,
            totalDebtAssets,
            IShareToken(_debtShareToken).totalSupply(),
            Rounding.BORROW_TO_ASSETS,
            Rounding.BORROW_TO_SHARES,
            ISilo.AssetType.Debt
        );

        if (borrowedShares == 0) revert ISilo.ZeroShares();
        if (borrowedAssets == 0) revert ISilo.ZeroAssets();

        if (_token != address(0) &&
            borrowedAssets > SiloMathLib.liquidity(_totalCollateralAssets, totalDebtAssets)
        ) {
            revert ISilo.NotEnoughLiquidity();
        }

        // add new debt
        _totalDebt.assets = totalDebtAssets + borrowedAssets;

        // `mint` checks if _spender is allowed to borrow on the account of _borrower. Hook receiver can
        // potentially reenter but the state is correct.
        IShareToken(_debtShareToken).mint(_args.borrower, _spender, borrowedShares);

        if (_token != address(0)) {
            // fee-on-transfer is ignored. If token reenters, state is already finalized, no harm done.
            IERC20(_token).safeTransfer(_args.receiver, borrowedAssets);
        }
    }

    /// @notice Determines the maximum amount (both in assets and shares) that a borrower can borrow
    /// @param _collateralConfig Configuration data for the collateral
    /// @param _debtConfig Configuration data for the debt
    /// @param _borrower The address of the borrower whose maximum borrow limit is being queried
    /// @param _totalDebtAssets The total debt assets in the system
    /// @param _totalDebtShares The total debt shares in the system
    /// @param _siloConfig address of SiloConfig contract
    /// @return assets The maximum amount in assets that can be borrowed
    /// @return shares The equivalent amount in shares for the maximum assets that can be borrowed
    function calculateMaxBorrow( // solhint-disable-line function-max-lines
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower,
        uint256 _totalDebtAssets,
        uint256 _totalDebtShares,
        ISiloConfig _siloConfig
    )
        internal
        view
        returns (uint256 assets, uint256 shares)
    {
        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.getAssetsDataForLtvCalculations(
            _collateralConfig,
            _debtConfig,
            _borrower,
            ISilo.OracleType.MaxLtv,
            0 /* no cache */
        );

        (
            uint256 sumOfBorrowerCollateralValue, uint256 borrowerDebtValue
        ) = SiloSolvencyLib.getPositionValues(ltvData, _collateralConfig.token, _debtConfig.token);

        uint256 maxBorrowValue = SiloMathLib.calculateMaxBorrowValue(
            _collateralConfig.maxLtv,
            sumOfBorrowerCollateralValue,
            borrowerDebtValue
        );

        (assets, shares) = maxBorrowValueToAssetsAndShares(
            maxBorrowValue,
            borrowerDebtValue,
            _borrower,
            _debtConfig.token,
            _debtConfig.debtShareToken,
            ltvData.debtOracle,
            _totalDebtAssets,
            _totalDebtShares
        );

        uint256 liquidityWithInterest = getLiquidity(_siloConfig);

        if (assets > liquidityWithInterest) {
            assets = liquidityWithInterest;

            // rounding must follow same flow as in `maxBorrowValueToAssetsAndShares()`
            shares = SiloMathLib.convertToShares(
                assets,
                _totalDebtAssets,
                _totalDebtShares,
                Rounding.MAX_BORROW_TO_SHARES,
                ISilo.AssetType.Debt
            );
        }

        if (assets != 0) {
            // sometimes even with rounding down, we need to do -1 wei to not revert on borrow
            unchecked { assets--; }
        }
    }

    function maxBorrow(ISiloConfig _siloConfig, address _borrower, bool _sameAsset)
        internal
        view
        returns (uint256 maxAssets, uint256 maxShares)
    {
        if (_siloConfig.hasDebtInOtherSilo(address(this), _borrower)) return (0, 0);

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;

        if (_sameAsset) {
            debtConfig = _siloConfig.getConfig(address(this));
            collateralConfig = debtConfig;
        } else {
            (collateralConfig, debtConfig) = _siloConfig.getConfigsForBorrow({_debtSilo: address(this)});
        }

        (uint256 totalDebtAssets, uint256 totalDebtShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(debtConfig, ISilo.AssetType.Debt);

        return calculateMaxBorrow(
            collateralConfig,
            debtConfig,
            _borrower,
            totalDebtAssets,
            totalDebtShares,
            _siloConfig
        );
    }

    function getLiquidity(ISiloConfig _siloConfig) internal view returns (uint256 liquidity) {
        ISiloConfig.ConfigData memory config = _siloConfig.getConfig(address(this));
        (liquidity,,) = getLiquidityAndAssetsWithInterest(config.interestRateModel, config.daoFee, config.deployerFee);
    }

    function getLiquidityAndAssetsWithInterest(address _interestRateModel, uint256 _daoFee, uint256 _deployerFee)
        internal
        view
        returns (uint256 liquidity, uint256 totalCollateralAssets, uint256 totalDebtAssets)
    {
        totalCollateralAssets = SiloStdLib.getTotalCollateralAssetsWithInterest(
            address(this),
            _interestRateModel,
            _daoFee,
            _deployerFee
        );

        totalDebtAssets = SiloStdLib.getTotalDebtAssetsWithInterest(address(this), _interestRateModel);
        liquidity = SiloMathLib.liquidity(totalCollateralAssets, totalDebtAssets);
    }

    /// @notice Calculates the maximum borrowable assets and shares
    /// @param _maxBorrowValue The maximum value that can be borrowed by the user
    /// @param _borrowerDebtValue The current debt value of the borrower
    /// @param _borrower The address of the borrower
    /// @param _debtToken Address of the debt token
    /// @param _debtShareToken Address of the debt share token
    /// @param _debtOracle Oracle used to get the value of the debt token
    /// @param _totalDebtAssets Total assets of the debt
    /// @param _totalDebtShares Total shares of the debt
    /// @return assets Maximum borrowable assets
    /// @return shares Maximum borrowable shares
    function maxBorrowValueToAssetsAndShares(
        uint256 _maxBorrowValue,
        uint256 _borrowerDebtValue,
        address _borrower,
        address _debtToken,
        address _debtShareToken,
        ISiloOracle _debtOracle,
        uint256 _totalDebtAssets,
        uint256 _totalDebtShares
    )
        internal
        view
        returns (uint256 assets, uint256 shares)
    {
        if (_maxBorrowValue == 0) {
            return (0, 0);
        }

        if (_borrowerDebtValue == 0) {
            uint256 oneDebtToken = 10 ** IERC20Metadata(_debtToken).decimals();

            uint256 oneDebtTokenValue = address(_debtOracle) == address(0)
                ? oneDebtToken
                : _debtOracle.quote(oneDebtToken, _debtToken);

            assets = _maxBorrowValue * _PRECISION_DECIMALS / oneDebtTokenValue;

            // when we borrow, we convertToShares with rounding.Up, to create higher debt, however here,
            // when we want to calculate "max borrow", we can not round.Up, because it can create issue with max ltv,
            // because we not creating debt here, we calculating max assets/shares, so we need to round.Down here
            shares = SiloMathLib.convertToShares(
                assets, _totalDebtAssets, _totalDebtShares, Rounding.MAX_BORROW_TO_SHARES, ISilo.AssetType.Debt
            );
        } else {
            uint256 shareBalance = IShareToken(_debtShareToken).balanceOf(_borrower);

            // on LTV calculation, we taking debt value, and we round UP when we calculating shares
            // so here, when we want to calculate shares from value, we need to round down.
            shares = _maxBorrowValue * shareBalance / _borrowerDebtValue; // by default rounding DOWN

            assets = SiloMathLib.convertToAssets(
                shares, _totalDebtAssets, _totalDebtShares, Rounding.MAX_BORROW_TO_ASSETS, ISilo.AssetType.Debt
            );
        }
    }
}
