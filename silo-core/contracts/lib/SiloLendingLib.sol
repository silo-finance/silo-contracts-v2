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
import {ShareTokenLib} from "./ShareTokenLib.sol";
import {SiloStorageLib} from "./SiloStorageLib.sol";
import {AssetTypes} from "./AssetTypes.sol";

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
    /// @return assets The amount of assets that was repaid
    /// @return shares The corresponding number of debt shares that were repaid
    function repay(
        IShareToken _debtShareToken,
        address _debtAsset,
        uint256 _assets,
        uint256 _shares,
        address _borrower,
        address _repayer
    ) internal returns (uint256 assets, uint256 shares) {
        if (_assets == 0 && _shares == 0) revert ISilo.ZeroAssets();

        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();

        uint256 totalDebtAssets = $.totalAssets[AssetTypes.DEBT];

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
        if (totalDebtAssets < assets) revert ISilo.RepayTooHigh();

        // subtract repayment from debt, save to unchecked because of above `totalDebtAssets < assets`
        unchecked { $.totalAssets[AssetTypes.DEBT] = totalDebtAssets - assets; }

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
    /// @return accruedInterest The total amount of interest accrued
    function accrueInterestForAsset(address _interestRateModel, uint256 _daoFee, uint256 _deployerFee)
        internal returns (uint256 accruedInterest)
    {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();

        uint64 lastTimestamp = $.interestRateTimestamp;

        // This is the first time, so we can return early and save some gas
        if (lastTimestamp == 0) {
            $.interestRateTimestamp = uint64(block.timestamp);
            return 0;
        }

        // Interest has already been accrued this block
        if (lastTimestamp == block.timestamp) {
            return 0;
        }

        uint256 totalFees;
        uint256 totalCollateralAssets = $.totalAssets[AssetTypes.COLLATERAL];
        uint256 totalDebtAssets = $.totalAssets[AssetTypes.DEBT];

        uint256 rcomp = IInterestRateModel(_interestRateModel).getCompoundInterestRateAndUpdate(
            totalCollateralAssets,
            totalDebtAssets,
            lastTimestamp
        );

        (
            $.totalAssets[AssetTypes.COLLATERAL], $.totalAssets[AssetTypes.DEBT], totalFees, accruedInterest
        ) = SiloMathLib.getCollateralAmountsWithInterest(
            totalCollateralAssets,
            totalDebtAssets,
            rcomp,
            _daoFee,
            _deployerFee
        );

        // update remaining contract state
        $.interestRateTimestamp = uint64(block.timestamp);

        // we operating on chunks (fees) of real tokens, so overflow should not happen
        // fee is simply to small to overflow on cast to uint192, even if, we will get lower fee
        unchecked { $.daoAndDeployerRevenue += uint192(totalFees); }
    }

    /// @notice Allows a user or a delegate to borrow assets against their collateral
    /// @dev The function checks for necessary conditions such as borrow possibility, enough liquidity, and zero
    /// values
    /// @param _debtShareToken address of debt share token
    /// @param _token address of underlying debt token
    /// @param _spender Address which initiates the borrowing action on behalf of the borrower
    /// @return borrowedAssets Actual number of assets that the user has borrowed
    /// @return borrowedShares Number of debt share tokens corresponding to the borrowed assets
    function borrow(
        address _debtShareToken,
        address _token,
        address _spender,
        ISilo.BorrowArgs memory _args
    )
        internal
        returns (uint256 borrowedAssets, uint256 borrowedShares)
    {
        if (_args.assets == 0 && _args.shares == 0) revert ISilo.ZeroAssets();

        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();

        uint256 totalDebtAssets = $.totalAssets[AssetTypes.DEBT];

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

        uint256 totalCollateralAssets = $.totalAssets[AssetTypes.COLLATERAL];

        if (_token != address(0) && borrowedAssets > SiloMathLib.liquidity(totalCollateralAssets, totalDebtAssets)) {
            revert ISilo.NotEnoughLiquidity();
        }

        // add new debt
        $.totalAssets[AssetTypes.DEBT] = totalDebtAssets + borrowedAssets;

        // TODO: remove reentrancy commens because they are misleading. Apply to other places deposit/repay/withdraw when we transfer tokens.
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
        // TODO: named params
        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.getAssetsDataForLtvCalculations(
            _collateralConfig,
            _debtConfig,
            _borrower,
            ISilo.OracleType.MaxLtv,
            ISilo.AccrueInterestInMemory.Yes,
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

        // TODO: named params
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

        // TODO: check also if shrares are 0
        if (assets == 0) return (0, 0);

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

    function maxBorrow(address _borrower, bool _sameAsset)
        internal
        view
        returns (uint256 maxAssets, uint256 maxShares)
    {
        ISiloConfig siloConfig = ShareTokenLib.siloConfig();
        if (siloConfig.hasDebtInOtherSilo(address(this), _borrower)) return (0, 0);

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;

        if (_sameAsset) {
            debtConfig = siloConfig.getConfig(address(this));
            collateralConfig = debtConfig;
        } else {
            (collateralConfig, debtConfig) = siloConfig.getConfigsForBorrow({_debtSilo: address(this)});
        }

        (uint256 totalDebtAssets, uint256 totalDebtShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(debtConfig, ISilo.AssetType.Debt);

        return calculateMaxBorrow(
            collateralConfig,
            debtConfig,
            _borrower,
            totalDebtAssets,
            totalDebtShares,
            siloConfig
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

        totalDebtAssets = SiloStdLib.getTotalDebtAssetsWithInterest(
            address(this),
            _interestRateModel
        );

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
        // TODO: rename to _debtAsset
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

            // TODO: remove decimals and if statement. Use _PRECISION_DECIMALS for quote and keep only one way of calculating max borrow.
            // asset is USDC, 6 decimals
            // quote token is ETH, 18 decimals

            // quote 1e18 USDC / decimals 1e6 = 1e12 (no decimals) / 2500 = 400000000e18
            // 400000000 * 2500 = 1e12

            // _maxBorrowValue in ETH = 10e18
            // oneDebtTokenValue = 400000000e18
            // oneDebtTokenValue / _PRECISION_DECIMALS
            // assets = 10e18 * 1e18 / 400000000e18 = 24999.999999 wei

            uint256 oneDebtTokenValue = address(_debtOracle) == address(0)
                ? oneDebtToken
                : _debtOracle.quote(oneDebtToken, _debtToken);

            // TODO: check if tests for different decimal assets are present. If not, add combinations for 18/6 and 6/6 decimals.
            // TODO: certora rule tests with different decimals
            assets = _maxBorrowValue.mulDiv(_PRECISION_DECIMALS, oneDebtTokenValue, Rounding.MAX_BORROW_TO_ASSETS);

            // when we borrow, we convertToShares with rounding.Up, to create higher debt, however here,
            // when we want to calculate "max borrow", we can not round.Up, because it can create issue with max ltv,
            // because we not creating debt here, we calculating max assets/shares, so we need to round.Down here
            shares = SiloMathLib.convertToShares(
                assets, _totalDebtAssets, _totalDebtShares, Rounding.MAX_BORROW_TO_SHARES, ISilo.AssetType.Debt
            );
        } else {
            // TODO: remove else based on above solution
            uint256 shareBalance = IShareToken(_debtShareToken).balanceOf(_borrower);

            // on LTV calculation, we taking debt value, and we round UP when we calculating shares
            // so here, when we want to calculate shares from value, we need to round down.
            shares = _maxBorrowValue.mulDiv(shareBalance, _borrowerDebtValue, Rounding.MAX_BORROW_TO_SHARES);

            assets = SiloMathLib.convertToAssets(
                shares, _totalDebtAssets, _totalDebtShares, Rounding.MAX_BORROW_TO_ASSETS, ISilo.AssetType.Debt
            );
        }
    }
}
