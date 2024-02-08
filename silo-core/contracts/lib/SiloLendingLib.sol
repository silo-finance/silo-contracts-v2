// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {SafeERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IERC20MetadataUpgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import {MathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";

import {IERC3156FlashBorrower} from "../interfaces/IERC3156FlashBorrower.sol";
import {ISiloOracle} from "../interfaces/ISiloOracle.sol";
import {ISilo} from "../interfaces/ISilo.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";
import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";
import {SiloStdLib} from "./SiloStdLib.sol";
import {SiloMathLib} from "./SiloMathLib.sol";

library SiloLendingLib {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using MathUpgradeable for uint256;

    bytes32 internal constant _FLASHLOAN_CALLBACK = keccak256("ERC3156FlashBorrower.onFlashLoan");

    uint256 internal constant _PRECISION_DECIMALS = 1e18;

    error FeeOverflow();

    /// @notice Allows a user or a delegate to borrow assets against their collateral
    /// @dev The function checks for necessary conditions such as borrow possibility, enough liquidity, and zero
    /// values
    /// @param _configData Contains configurations such as associated share tokens and underlying tokens
    /// @param _assets Number of assets the borrower intends to borrow. Use 0 if shares are provided.
    /// @param _shares Number of shares corresponding to the assets that the borrower intends to borrow. Use 0 if
    /// assets are provided.
    /// @param _receiver Address that will receive the borrowed assets
    /// @param _borrower The user who is borrowing the assets
    /// @param _spender Address which initiates the borrowing action on behalf of the borrower
    /// @param _totalDebt Current total outstanding debt in the system
    /// @param _totalCollateralAssets Total collateralized assets currently in the system
    /// @return borrowedAssets Actual number of assets that the user has borrowed
    /// @return borrowedShares Number of debt share tokens corresponding to the borrowed assets
    function borrow(
        ISiloConfig.ConfigData memory _configData,
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        address _borrower,
        address _spender,
        ISilo.Assets storage _totalDebt,
        uint256 _totalCollateralAssets
    ) internal returns (uint256 borrowedAssets, uint256 borrowedShares) {
        if (_assets == 0 && _shares == 0) revert ISilo.ZeroAssets();

        if (!borrowPossible(_configData.protectedShareToken, _configData.collateralShareToken, _borrower)) {
            revert ISilo.BorrowNotPossible();
        }

        IShareToken debtShareToken = IShareToken(_configData.debtShareToken);
        uint256 totalDebtAssets = _totalDebt.assets;

        (borrowedAssets, borrowedShares) = SiloMathLib.convertToAssetsAndToShares(
            _assets,
            _shares,
            totalDebtAssets,
            debtShareToken.totalSupply(),
            MathUpgradeable.Rounding.Down,
            MathUpgradeable.Rounding.Up,
            ISilo.AssetType.Debt
        );

        if (borrowedShares == 0) revert ISilo.ZeroShares();
        if (borrowedAssets == 0) revert ISilo.ZeroAssets();

        if (borrowedAssets > SiloMathLib.liquidity(_totalCollateralAssets, totalDebtAssets)) {
            revert ISilo.NotEnoughLiquidity();
        }

        // add new debt
        _totalDebt.assets = totalDebtAssets + borrowedAssets;
        // `mint` checks if _spender is allowed to borrow on the account of _borrower. Hook receiver can
        // potentially reenter but the state is correct.
        debtShareToken.mint(_borrower, _spender, borrowedShares);
        // fee-on-transfer is ignored. If token reenters, state is already finalized, no harm done.
        IERC20Upgradeable(_configData.token).safeTransfer(_receiver, borrowedAssets);
    }

    /// @notice Executes a flash loan, sending the requested amount to the receiver and expecting it back with a fee
    /// @param _config Configuration data relevant to the silo asset borrowed
    /// @param _siloData Storage containing data related to fees
    /// @param _receiver The entity that will receive the flash loan and is expected to return it with a fee
    /// @param _token The token that is being borrowed in the flash loan
    /// @param _amount The amount of tokens to be borrowed
    /// @param _data Additional data to be passed to the flash loan receiver
    /// @return success A boolean indicating if the flash loan was successful
    function flashLoan(
        ISiloConfig _config,
        ISilo.SiloData storage _siloData,
        IERC3156FlashBorrower _receiver,
        address _token,
        uint256 _amount,
        bytes calldata _data
    )
        external
        returns (bool success)
    {
        // flashFee will revert for wrong token
        uint256 fee = SiloStdLib.flashFee(_config, _token, _amount);
        if (fee > type(uint192).max) revert FeeOverflow();

        IERC20Upgradeable(_token).safeTransfer(address(_receiver), _amount);

        if (_receiver.onFlashLoan(msg.sender, _token, _amount, fee, _data) != _FLASHLOAN_CALLBACK) {
            revert ISilo.FlashloanFailed();
        }

        IERC20Upgradeable(_token).safeTransferFrom(address(_receiver), address(this), _amount + fee);

        // cast safe, because we checked `fee > type(uint192).max`
        _siloData.daoAndDeployerFees += uint192(fee);

        success = true;
    }

    /// @notice Allows repaying borrowed assets either partially or in full
    /// @param _configData Configuration data relevant to the silo asset
    /// @param _assets The amount of assets to repay. Use 0 if shares are used.
    /// @param _shares The number of corresponding shares associated with the debt. Use 0 if assets are used.
    /// @param _borrower The account that has the debt
    /// @param _repayer The account that is repaying the debt
    /// @param _totalDebt The storage reference for the total amount of debt assets
    /// @return assets The amount of assets that was repaid
    /// @return shares The corresponding number of debt shares that were repaid
    function repay(
        ISiloConfig.ConfigData memory _configData,
        uint256 _assets,
        uint256 _shares,
        address _borrower,
        address _repayer,
        ISilo.Assets storage _totalDebt
    ) internal returns (uint256 assets, uint256 shares) {
        if (_assets == 0 && _shares == 0) revert ISilo.ZeroAssets();

        IShareToken debtShareToken = IShareToken(_configData.debtShareToken);
        uint256 totalDebtAssets = _totalDebt.assets;

        (assets, shares) = SiloMathLib.convertToAssetsAndToShares(
            _assets,
            _shares,
            totalDebtAssets,
            debtShareToken.totalSupply(),
            MathUpgradeable.Rounding.Up,
            MathUpgradeable.Rounding.Down,
            ISilo.AssetType.Debt
        );

        if (shares == 0) revert ISilo.ZeroShares();

        // subtract repayment from debt
        _totalDebt.assets = totalDebtAssets - assets;

        // Anyone can repay anyone's debt so no approval check is needed. If hook receiver reenters then
        // no harm done because state changes are completed.
        debtShareToken.burn(_borrower, _repayer, shares);
        // fee-on-transfer is ignored
        // Reentrancy is possible only for view methods (read-only reentrancy),
        // so no harm can be done as the state is already updated.
        // We do not expect the silo to work with any malicious token that will not send tokens back.
        IERC20Upgradeable(_configData.token).safeTransferFrom(_repayer, address(this), assets);
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

    /// @notice Determines the maximum amount (both in assets and shares) that a borrower can borrow
    /// @param _collateralConfig Configuration data for the collateral
    /// @param _debtConfig Configuration data for the debt
    /// @param _borrower The address of the borrower whose maximum borrow limit is being queried
    /// @param _totalDebtAssets The total debt assets in the system
    /// @param _totalDebtShares The total debt shares in the system
    /// @param _siloConfig address of SiloConfig contract
    /// @return assets The maximum amount in assets that can be borrowed
    /// @return shares The equivalent amount in shares for the maximum assets that can be borrowed
    function maxBorrow( // solhint-disable-line function-max-lines
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower,
        uint256 _totalDebtAssets,
        uint256 _totalDebtShares,
        ISiloConfig _siloConfig
    )
        external
        view
        returns (uint256 assets, uint256 shares)
    {
        if (!borrowPossible(_debtConfig.protectedShareToken, _debtConfig.collateralShareToken, _borrower)) {
            return (0, 0);
        }

        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.getAssetsDataForLtvCalculations(
            _collateralConfig,
            _debtConfig,
            _borrower,
            ISilo.OracleType.MaxLtv,
            ISilo.AccrueInterestInMemory.Yes,
            0 /* no cached balance */
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
                borrowerDebtValue == 0 ? MathUpgradeable.Rounding.Up : MathUpgradeable.Rounding.Down,
                ISilo.AssetType.Debt
            );
        }
    }

    function getLiquidity(ISiloConfig _config) public view returns (uint256 liquidity) {
        ISiloConfig.ConfigData memory config = _config.getConfig(address(this));

        uint256 totalCollateralAssets = SiloStdLib.getTotalCollateralAssetsWithInterest(
            address(this),
            config.interestRateModel,
            config.daoFee,
            config.deployerFee
        );

        uint256 totalDebtAssets = SiloStdLib.getTotalDebtAssetsWithInterest(
            address(this),
            config.interestRateModel
        );

        liquidity = SiloMathLib.liquidity(totalCollateralAssets, totalDebtAssets);
    }

    /// @notice Checks if a borrower can borrow
    /// @param _protectedShareToken Address of the protected share token
    /// @param _collateralShareToken Address of the collateral share token
    /// @param _borrower The address of the borrower being checked
    /// @return possible `true` if the borrower can borrow, `false` otherwise
    function borrowPossible(
        address _protectedShareToken,
        address _collateralShareToken,
        address _borrower
    ) public view returns (bool possible) {
        // _borrower cannot have any collateral deposited
        possible = IShareToken(_protectedShareToken).balanceOf(_borrower) == 0
            && IShareToken(_collateralShareToken).balanceOf(_borrower) == 0;
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
            uint256 oneDebtToken = 10 ** IERC20MetadataUpgradeable(_debtToken).decimals();

            uint256 oneDebtTokenValue = address(_debtOracle) == address(0)
                ? oneDebtToken
                : _debtOracle.quote(oneDebtToken, _debtToken);

            assets = _maxBorrowValue * _PRECISION_DECIMALS / oneDebtTokenValue;

            shares = SiloMathLib.convertToShares(
                assets, _totalDebtAssets, _totalDebtShares, MathUpgradeable.Rounding.Up, ISilo.AssetType.Debt
            );
        } else {
            uint256 shareBalance = IShareToken(_debtShareToken).balanceOf(_borrower);

            // on LTV calculation, we taking debt value, and we round UP when we calculating shares
            // so here, when we want to calculate shares from value, we need to round down.
            shares = _maxBorrowValue * shareBalance / _borrowerDebtValue; // by default rounding DOWN

            assets = SiloMathLib.convertToAssets(
                shares, _totalDebtAssets, _totalDebtShares, MathUpgradeable.Rounding.Down, ISilo.AssetType.Debt
            );
        }
    }
}
