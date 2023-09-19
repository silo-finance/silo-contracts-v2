// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {MathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";

import {ISiloOracle} from "../interfaces/ISiloOracle.sol";
import {ISiloLiquidation} from "../interfaces/ISiloLiquidation.sol";
import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";
import {SiloStdLib, ISiloConfig, IShareToken, ISilo} from "./SiloStdLib.sol";
import {SiloERC4626Lib} from "./SiloERC4626Lib.sol";
import {SiloLiquidationLib} from "./SiloLiquidationLib.sol";

library SiloSolvencyLib {
    struct LtvData {
        // TODO rename +borrower
        ISiloOracle debtOracle;
        ISiloOracle collateralOracle;
        uint256 protectedAssets;
        uint256 collateralAssets;
        uint256 debtAssets;
    }

    uint256 internal constant _PRECISION_DECIMALS = 1e18;
    uint256 internal constant _BASIS_POINTS = 1e4;

    /// @dev this method expect accrue interest were executed before
    /// it transfer sToken from borrower to liquidator
    function liquidationSTransfer(
        address _borrower,
        address _liquidator,
        uint256 _amountToLiquidate,
        uint256 _totalAssets,
        IShareToken _shareToken
    ) internal {
        // we already accrued interest, so we can work directly on assets
        uint256 shares = SiloERC4626Lib.convertToShares(
            _amountToLiquidate, _totalAssets, _shareToken.totalSupply(), MathUpgradeable.Rounding.Down
        );

        _shareToken.liquidationTransfer(_borrower, _liquidator, shares);
    }

    /// @dev withdraws assets
    function withdrawCollateralToLiquidator(
        ISiloConfig.ConfigData memory _collateralConfig,
        uint256 _withdrawAssetsFromCollateral,
        uint256 _withdrawAssetsFromProtected,
        address _borrower,
        address _liquidator,
        ISilo.Assets storage _totalCollateral,
        ISilo.Assets storage _totalProtected,
        function() view returns (uint256) _liquidity
    ) internal {
        if (_withdrawAssetsFromProtected != 0) {
            SiloERC4626Lib.withdraw(
                _collateralConfig.token,
                _collateralConfig.protectedShareToken,
                SiloERC4626Lib.WithdrawParams({
                    assets: _withdrawAssetsFromProtected,
                    shares: 0,
                    receiver: _liquidator,
                    owner: _borrower,
                    spender: _borrower,
                    assetType: ISilo.AssetType.Protected
                }),
                _totalProtected,
                _liquidity
            );
        }

        if (_withdrawAssetsFromCollateral != 0) {
            SiloERC4626Lib.withdraw(
                _collateralConfig.token,
                _collateralConfig.collateralShareToken,
                SiloERC4626Lib.WithdrawParams({
                    assets: _withdrawAssetsFromCollateral,
                    shares: 0,
                    receiver: _liquidator,
                    owner: _borrower,
                    spender: _borrower,
                    assetType: ISilo.AssetType.Collateral
                }),
                _totalCollateral,
                _liquidity
            );
        }
    }

    /// @dev withdraws sTokens
    function withdrawSCollateralToLiquidator(
        address _collateralShareToken,
        address _collateralProtectedShareToken,
        uint256 _withdrawAssetsFromCollateral,
        uint256 _withdrawAssetsFromProtected,
        address _borrower,
        address _liquidator,
        ISilo.Assets storage _totalCollateral,
        ISilo.Assets storage _totalProtected
    ) internal {
        if (_withdrawAssetsFromProtected != 0) {
            liquidationSTransfer(
                _borrower,
                _liquidator,
                _withdrawAssetsFromProtected,
                _totalProtected.assets,
                IShareToken(_collateralProtectedShareToken)
            );
        }

        if (_withdrawAssetsFromCollateral != 0) {
            liquidationSTransfer(
                _borrower,
                _liquidator,
                _withdrawAssetsFromCollateral,
                _totalCollateral.assets,
                IShareToken(_collateralShareToken)
            );
        }
    }

    function ltvAfterLiquidation( // TODO better name
        SiloSolvencyLib.LtvData memory _ltvData,
        address _collateralToken,
        address _debtToken
    )
        internal
        view
        returns (uint256 ltvInBp, uint256 totalBorrowerDebtValue, uint256 totalBorrowerCollateralValue)
    {
        (totalBorrowerDebtValue, totalBorrowerCollateralValue) =
            SiloSolvencyLib.getPositionValues(_ltvData, _collateralToken, _debtToken);

        ltvInBp = totalBorrowerDebtValue * _BASIS_POINTS / totalBorrowerCollateralValue;
    }

    /// @dev it will be user responsibility to check profit
    function getExactLiquidationAmounts(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _user,
        uint256 _debtToCover,
        uint256 _liquidationFeeInBp,
        bool _selfLiquidation
    )
        internal
        view
        returns (uint256 withdrawAssetsFromCollateral, uint256 withdrawAssetsFromProtected, uint256 repayDebtAssets)
    {
        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.getAssetsDataForLtvCalculations(
            _collateralConfig, _debtConfig, _user, ISilo.OracleType.Solvency, ISilo.AccrueInterestInMemory.No
        );

        uint256 borrowerCollateralToLiquidate;

        (
            borrowerCollateralToLiquidate, repayDebtAssets
        ) = liquidationPreview(
            ltvData,
            _collateralConfig.lt,
            _collateralConfig.token,
            _debtConfig.token,
            _debtToCover,
            _liquidationFeeInBp,
            _selfLiquidation
        );

        (
            withdrawAssetsFromCollateral, withdrawAssetsFromProtected
        ) = splitReceiveCollateralToLiquidate(borrowerCollateralToLiquidate, ltvData.protectedAssets);
    }

    /// @return receiveCollateralAssets collateral + protected to liquidate
    /// @return repayDebtAssets
    function liquidationPreview(
        SiloSolvencyLib.LtvData memory _ltvData,
        uint256 _collateralLt,
        address _collateralConfigToken,
        address _debtConfigToken,
        uint256 _debtToCover,
        uint256 _liquidationFeeInBp,
        bool _selfLiquidation
    )
        internal
        view
        returns (
            uint256 receiveCollateralAssets,
            uint256 repayDebtAssets
        )
    {
        uint256 totalCollateralAssets = _ltvData.collateralAssets + _ltvData.protectedAssets;

        if (_ltvData.debtAssets == 0 || totalCollateralAssets == 0) revert ISiloLiquidation.UserIsSolvent();

        (
            uint256 ltvAfterInBp, uint256 totalBorrowerDebtValue, uint256 totalBorrowerCollateralValue
        ) = ltvAfterLiquidation(_ltvData, _collateralConfigToken, _debtConfigToken);

        if (!_selfLiquidation && _collateralLt > ltvAfterInBp) revert ISiloLiquidation.UserIsSolvent();

        // TODO do not do full liquidation, do partial
        if (ltvAfterInBp >= _BASIS_POINTS) { // in case of bad debt we return all
            return (totalCollateralAssets, _ltvData.debtAssets);
        }

        (receiveCollateralAssets, repayDebtAssets, ltvAfterInBp) = SiloLiquidationLib.calculateExactLiquidationAmounts(
            _debtToCover,
            totalBorrowerDebtValue,
            _ltvData.debtAssets,
            totalBorrowerCollateralValue,
            totalCollateralAssets,
            _liquidationFeeInBp
        );

        if (receiveCollateralAssets == 0 || repayDebtAssets == 0) revert ISiloLiquidation.UserIsSolvent();

        if (ltvAfterInBp != 0) { // it can be 0 in case of full liquidation
            if (!_selfLiquidation && ltvAfterInBp < SiloLiquidationLib.minAcceptableLT(_collateralLt)) {
                revert ISiloLiquidation.LiquidationTooBig();
            }
        }
    }

    /// @dev check if config was given in correct order
    /// @return orderCorrect TRUE means that order is correct OR `_borrower` has no debt and we can not really tell
    function validConfigOrder(
        address _collateralConfigDebtShareToken,
        address _debtConfigDebtShareToken,
        address _borrower
    ) internal view returns (bool orderCorrect) {
        uint256 debtShareTokenBalance = IShareToken(_debtConfigDebtShareToken).balanceOf(_borrower);

        return
            debtShareTokenBalance == 0 ? IShareToken(_collateralConfigDebtShareToken).balanceOf(_borrower) == 0 : true;
    }

    // solhint-disable-next-line function-max-lines
    function getAssetsDataForLtvCalculations(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower,
        ISilo.OracleType _oracleType,
        ISilo.AccrueInterestInMemory _accrueInMemory
    ) internal view returns (LtvData memory ltvData) {
        // When calculating maxLtv, use maxLtv oracle. If maxLtv oracle is not set, fallback to solvency oracle
        ltvData.debtOracle = _oracleType == ISilo.OracleType.MaxLtv && _debtConfig.maxLtvOracle != address(0)
            ? ISiloOracle(_debtConfig.maxLtvOracle)
            : ISiloOracle(_debtConfig.solvencyOracle);
        ltvData.collateralOracle = _oracleType == ISilo.OracleType.MaxLtv
            && _collateralConfig.maxLtvOracle != address(0)
            ? ISiloOracle(_collateralConfig.maxLtvOracle)
            : ISiloOracle(_collateralConfig.solvencyOracle);

        uint256 totalAssets;
        uint256 totalShares;
        uint256 shares;

        (shares, totalShares) = SiloStdLib.getSharesAndTotalSupply(_collateralConfig.protectedShareToken, _borrower);
        totalAssets = ISilo(_collateralConfig.silo).getProtectedAssets();
        ltvData.protectedAssets =
            SiloERC4626Lib.convertToAssets(shares, totalAssets, totalShares, MathUpgradeable.Rounding.Down);

        (shares, totalShares) = SiloStdLib.getSharesAndTotalSupply(_collateralConfig.collateralShareToken, _borrower);
        totalAssets = SiloStdLib.getTotalAsssetsWithInterest(
            _collateralConfig.silo,
            _collateralConfig.interestRateModel,
            ISilo(_collateralConfig.silo).getCollateralAssets(),
            _collateralConfig.daoFeeInBp,
            _collateralConfig.deployerFeeInBp,
            ISilo.AssetType.Collateral,
            _accrueInMemory
        );
        ltvData.collateralAssets =
            SiloERC4626Lib.convertToAssets(shares, totalAssets, totalShares, MathUpgradeable.Rounding.Down);

        (shares, totalShares) = SiloStdLib.getSharesAndTotalSupply(_debtConfig.debtShareToken, _borrower);
        totalAssets = SiloStdLib.getTotalAsssetsWithInterest(
            _debtConfig.silo,
            _debtConfig.interestRateModel,
            0,
            _debtConfig.daoFeeInBp,
            _debtConfig.deployerFeeInBp,
            ISilo.AssetType.Debt,
            _accrueInMemory
        );

        ltvData.debtAssets =
            SiloERC4626Lib.convertToAssets(shares, totalAssets, totalShares, MathUpgradeable.Rounding.Up);
    }

    function getPositionValues(LtvData memory _ltvData, address _collateralAsset, address _debtAsset)
        internal
        view
        returns (uint256 collateralValue, uint256 debtValue)
    {
        uint256 totalCollateralAssets = _ltvData.protectedAssets + _ltvData.collateralAssets;
        // if no oracle is set, assume price 1
        collateralValue = address(_ltvData.collateralOracle) != address(0)
            ? _ltvData.collateralOracle.quote(totalCollateralAssets, _collateralAsset)
            : totalCollateralAssets;

        // if no oracle is set, assume price 1
        debtValue = address(_ltvData.debtOracle) != address(0)
            ? _ltvData.debtOracle.quote(_ltvData.debtAssets, _debtAsset)
            : _ltvData.debtAssets;
    }

    /// @dev Calculates LTV for user. It is used in core logic. Non-view function is needed in case the oracle
    ///      has to write some data to storage to protect ie. from read re-entracy like in curve pools.
    /// @return ltv Loan-to-Value
    function getLtv(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower,
        ISilo.OracleType _oracleType,
        ISilo.AccrueInterestInMemory _accrueInMemory
    ) internal view returns (uint256 ltv) {
        LtvData memory ltvData =
            getAssetsDataForLtvCalculations(_collateralConfig, _debtConfig, _borrower, _oracleType, _accrueInMemory);

        if (ltvData.debtAssets == 0) return 0;

        (uint256 debtValue, uint256 collateralValue) =
            getPositionValues(ltvData, _collateralConfig.token, _debtConfig.token);

        ltv = debtValue * _PRECISION_DECIMALS / collateralValue;
    }

    function isSolvent(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower,
        ISilo.AccrueInterestInMemory _accrueInMemory
    ) internal view returns (bool) {
        uint256 ltv = getLtv(_collateralConfig, _debtConfig, _borrower, ISilo.OracleType.Solvency, _accrueInMemory);
        return ltv < _collateralConfig.lt;
    }

    function isBelowMaxLtv(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower,
        ISilo.AccrueInterestInMemory _accrueInMemory
    ) internal view returns (bool) {
        uint256 ltv = getLtv(_collateralConfig, _debtConfig, _borrower, ISilo.OracleType.MaxLtv, _accrueInMemory);
        return ltv < _collateralConfig.maxLtv;
    }

    /// @dev protected collateral is prioritized
    /// @param _borrowerProtectedAssets available users protected collateral
    function splitReceiveCollateralToLiquidate(uint256 _collateralToLiquidate, uint256 _borrowerProtectedAssets)
        internal
        pure
        returns (uint256 withdrawAssetsFromCollateral, uint256 withdrawAssetsFromProtected)
    {
        unchecked {
            (
                withdrawAssetsFromProtected, withdrawAssetsFromCollateral
            ) = _collateralToLiquidate > _borrowerProtectedAssets
                // safe to unchecked because of above condition
                ? (_collateralToLiquidate - _borrowerProtectedAssets, _borrowerProtectedAssets)
                : (0, _collateralToLiquidate);
        }
    }
}
