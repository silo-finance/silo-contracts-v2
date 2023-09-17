// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {MathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";

import {ISiloOracle} from "../interfaces/ISiloOracle.sol";
import {ISiloLiquidation} from "../interfaces/ISiloLiquidation.sol";
import {SiloStdLib, ISiloConfig, IShareToken, ISilo} from "./SiloStdLib.sol";
import {SiloERC4626Lib} from "./SiloERC4626Lib.sol";
import {SiloLiquidationLib} from "./SiloLiquidationLib.sol";

library SiloSolvencyLib {
    struct LtvData { // TODO rename +borrower
        ISiloOracle debtOracle;
        ISiloOracle collateralOracle;
        uint256 debtAssets;
        uint256 totalCollateralAssets;
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
            _amountToLiquidate,
            _totalAssets,
            _shareToken.totalSupply(),
            MathUpgradeable.Rounding.Down
        );

        _shareToken.liquidationTransfer(_borrower, _liquidator, shares);
    }

    function getAssetAndSharesWithInterest(
        address _silo,
        address _interestRateModel,
        address _token,
        address _shareToken,
        address _borrower,
        ISilo.AccrueInterestInMemory _accrueInMemory,
        MathUpgradeable.Rounding _rounding
    ) internal view returns (uint256 assets, uint256 shares) {
        shares = IShareToken(_shareToken).balanceOf(_borrower);

        if (shares == 0) {
            return (0, 0);
        }

        assets = SiloERC4626Lib.convertToAssets(
            shares,
            /// @dev amountWithInterest is not needed for core LTV calculations because accrueInterest was just called
            ///      and storage data is fresh.
            _accrueInMemory == ISilo.AccrueInterestInMemory.Yes
                ? SiloStdLib.amountWithInterest(
                    _token, ISilo(_silo).getDebtAssets(), _interestRateModel // TODO why debt? bug?
                )
                : ISilo(_silo).getDebtAssets(), // TODO why debt? bug?
            IShareToken(_shareToken).totalSupply(),
            _rounding
        );
    }

    /// @dev it will be user responsibility to check profit
    function liquidationPreview(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _user,
        uint256 _debtToCover,
        uint256 _liquidationFeeInBp,
        bool _selfLiquidation
    )
        internal
        view
        returns (uint256 receiveCollateralAssets, uint256 repayDebtAssets)
    {
        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.getAssetsDataForLtvCalculations(
            _collateralConfig, _debtConfig, _user, ISilo.OracleType.Solvency, ISilo.AccrueInterestInMemory.No
        );

        if (ltvData.debtAssets == 0 || ltvData.totalCollateralAssets == 0) revert ISiloLiquidation.UserIsSolvent();

        (
            uint256 totalBorrowerDebtValue,
            uint256 totalBorrowerCollateralValue
        ) = SiloSolvencyLib.getPositionValues(ltvData, _collateralConfig.token, _debtConfig.token);

        uint256 ltvInBp = totalBorrowerDebtValue * _BASIS_POINTS / totalBorrowerCollateralValue;

        if (!_selfLiquidation && _collateralConfig.lt > ltvInBp) revert ISiloLiquidation.UserIsSolvent();

        if (ltvInBp >= _BASIS_POINTS) { // in case of bad debt we return all
            return (ltvData.totalCollateralAssets, ltvData.debtAssets);
        }

        (receiveCollateralAssets, repayDebtAssets, ltvInBp) = SiloLiquidationLib.calculateExactLiquidationAmounts(
            _debtToCover,
            totalBorrowerDebtValue,
            ltvData.debtAssets,
            totalBorrowerCollateralValue,
            ltvData.totalCollateralAssets,
            _liquidationFeeInBp
        );

        if (receiveCollateralAssets == 0 || repayDebtAssets == 0) revert ISiloLiquidation.InsufficientLiquidation();

        if (ltvInBp != 0) { // it can be 0 in case of full liquidation
            if (!_selfLiquidation && ltvInBp < SiloLiquidationLib.minAcceptableLT(_collateralConfig.lt)) {
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
    )
        internal
        view
        returns (bool orderCorrect)
    {
        uint256 debtShareTokenBalance = IShareToken(_debtConfigDebtShareToken).balanceOf(_borrower);

        return debtShareTokenBalance == 0
            ? IShareToken(_collateralConfigDebtShareToken).balanceOf(_borrower) == 0
            : true;
    }

    function getAssetsDataForLtvCalculations(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower,
        ISilo.OracleType _oracleType,
        ISilo.AccrueInterestInMemory _accrueInMemory
    ) internal view returns (LtvData memory ltvData) {
        // If LTV is needed for solvency, ltOracle should be used. If ltOracle is not set, fallback to ltvOracle.
        ltvData.debtOracle = _oracleType == ISilo.OracleType.MaxLtv && _debtConfig.maxLtvOracle != address(0)
            ? ISiloOracle(_debtConfig.maxLtvOracle)
            : ISiloOracle(_debtConfig.solvencyOracle);
        ltvData.collateralOracle = _oracleType == ISilo.OracleType.MaxLtv
            && _collateralConfig.maxLtvOracle != address(0)
                ? ISiloOracle(_collateralConfig.maxLtvOracle)
                : ISiloOracle(_collateralConfig.solvencyOracle);

        (ltvData.debtAssets,) = getAssetAndSharesWithInterest(
            _debtConfig.silo,
            _debtConfig.interestRateModel,
            _debtConfig.token,
            _debtConfig.debtShareToken,
            _borrower,
            _accrueInMemory,
            MathUpgradeable.Rounding.Up
        );

        (ltvData.totalCollateralAssets,) = getAssetAndSharesWithInterest(
            _collateralConfig.silo,
            _collateralConfig.interestRateModel,
            _collateralConfig.token,
            _collateralConfig.protectedShareToken,
            _borrower,
            _accrueInMemory,
            MathUpgradeable.Rounding.Down
        );

        (uint256 collateralAssets,) = getAssetAndSharesWithInterest(
            _collateralConfig.silo,
            _collateralConfig.interestRateModel,
            _collateralConfig.token,
            _collateralConfig.collateralShareToken,
            _borrower,
            _accrueInMemory,
            MathUpgradeable.Rounding.Down
        );

        /// @dev sum of assets cannot be bigger than total supply which must fit in uint256
        unchecked {
            ltvData.totalCollateralAssets += collateralAssets;
        }
    }

    function getPositionValues(LtvData memory _ltvData, address _collateralAsset, address _debtAsset)
        internal
        view
        returns (uint256 collateralValue, uint256 debtValue)
    {
        // if no oracle is set, assume price 1
        collateralValue = address(_ltvData.collateralOracle) != address(0)
            ? _ltvData.collateralOracle.quote(_ltvData.totalCollateralAssets, _collateralAsset)
            : _ltvData.totalCollateralAssets;

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

        (
            uint256 debtValue, uint256 collateralValue
        ) = getPositionValues(ltvData, _collateralConfig.token, _debtConfig.token);

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

    function splitReceiveCollateralToLiquidate(
        uint256 _receiveCollateralToLiquidate,
        address _collateralSilo,
        address _interestRateModel,
        address _token,
        address _shareToken,
        address _borrower
    )
        internal
        view
        returns (uint256 withdrawAssetsFromCollateral, uint256 withdrawAssetsFromProtected)
    {
        (uint256 borrowerCollateralAssets,) = SiloSolvencyLib.getAssetAndSharesWithInterest(
            _collateralSilo,
            _interestRateModel,
            _token,
            _shareToken,
            _borrower,
            ISilo.AccrueInterestInMemory.No,
            MathUpgradeable.Rounding.Down
        );

        unchecked {
            (withdrawAssetsFromCollateral, withdrawAssetsFromProtected) =
                _receiveCollateralToLiquidate > borrowerCollateralAssets
                    // safe to unchecked because of above condition
                    ? (borrowerCollateralAssets, _receiveCollateralToLiquidate - borrowerCollateralAssets)
                    : (_receiveCollateralToLiquidate, 0);
        }
    }
}
