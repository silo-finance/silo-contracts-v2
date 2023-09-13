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
        address debtAsset;
        address collateralAsset;
        ISiloOracle debtOracle;
        ISiloOracle collateralOracle;
        uint256 debtAssets;
        uint256 totalCollateralAssets;
        uint256 ltInBP;
        uint256 maxLtv;
    }

    uint256 internal constant _PRECISION_DECIMALS = 1e18;
    uint256 internal constant _BASIS_POINTS = 1e4;

    function assetBalanceOfWithInterest(
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
        uint256 _liquidationFeeInBP
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
        ) = SiloSolvencyLib.getPositionValues(ltvData);

        uint256 ltvInBP = totalBorrowerDebtValue * _BASIS_POINTS / totalBorrowerCollateralValue;

        if (ltvData.ltInBP > ltvInBP) revert ISiloLiquidation.UserIsSolvent();

        if (ltvInBP >= _BASIS_POINTS) { // in case of bad debt we return all
            return (ltvData.totalCollateralAssets, ltvData.debtAssets);
        }

        (receiveCollateralAssets, repayDebtAssets, ltvInBP) = SiloLiquidationLib.calculateExactLiquidationAmounts(
            _debtToCover,
            totalBorrowerDebtValue,
            ltvData.debtAssets,
            totalBorrowerCollateralValue,
            ltvData.totalCollateralAssets,
            _liquidationFeeInBP
        );

        if (receiveCollateralAssets == 0 || repayDebtAssets == 0) revert ISiloLiquidation.InsufficientLiquidation();

        if (ltvInBP != 0) { // it can be 0 in case of full liquidation
            if (ltvInBP < SiloLiquidationLib.minAcceptableLT(ltvData.ltInBP)) {
                revert ISiloLiquidation.LiquidationTooBig();
            }
        }
    }

    function getAssetsDataForLtvCalculations( // solhint-disable function-max-lines
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower,
        ISilo.OracleType _oracleType,
        ISilo.AccrueInterestInMemory _accrueInMemory
    ) internal view returns (LtvData memory ltvData) {
        uint256 debtShareTokenBalance = IShareToken(_debtConfig.debtShareToken).balanceOf(_borrower);

        // check if config was given in correct order
        if (debtShareTokenBalance == 0) {
            debtShareTokenBalance = IShareToken(_collateralConfig.debtShareToken).balanceOf(_borrower);

            if (debtShareTokenBalance == 0) { // nothing borrowed
                return ltvData;
            } else { // configs in wrong order, reverse order
                (_debtConfig, _collateralConfig) = (_collateralConfig, _debtConfig);
            }
        }

        ltvData.debtAsset = _debtConfig.token;
        ltvData.collateralAsset = _collateralConfig.token;
        ltvData.ltInBP = _collateralConfig.lt;
        ltvData.maxLtv = _collateralConfig.maxLtv;

        // If LTV is needed for solvency, ltOracle should be used. If ltOracle is not set, fallback to ltvOracle.
        ltvData.debtOracle = _oracleType == ISilo.OracleType.MaxLtv && _debtConfig.maxLtvOracle != address(0)
            ? ISiloOracle(_debtConfig.maxLtvOracle)
            : ISiloOracle(_debtConfig.solvencyOracle);
        ltvData.collateralOracle = _oracleType == ISilo.OracleType.MaxLtv
            && _collateralConfig.maxLtvOracle != address(0)
                ? ISiloOracle(_collateralConfig.maxLtvOracle)
                : ISiloOracle(_collateralConfig.solvencyOracle);

        (ltvData.debtAssets,) = assetBalanceOfWithInterest(
            _debtConfig.silo,
            _debtConfig.interestRateModel,
            _debtConfig.token,
            _debtConfig.debtShareToken,
            _borrower,
            _accrueInMemory,
            MathUpgradeable.Rounding.Up
        );

        (ltvData.totalCollateralAssets,) = assetBalanceOfWithInterest(
            _collateralConfig.silo,
            _collateralConfig.interestRateModel,
            _collateralConfig.token,
            _collateralConfig.protectedShareToken,
            _borrower,
            _accrueInMemory,
            MathUpgradeable.Rounding.Down
        );

        (uint256 collateralAssets,) = assetBalanceOfWithInterest(
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

    function getPositionValues(LtvData memory _ltvData)
        internal
        view
        returns (uint256 collateralValue, uint256 debtValue)
    {
        // if no oracle is set, assume price 1
        collateralValue = address(_ltvData.collateralOracle) != address(0)
            ? _ltvData.collateralOracle.quote(_ltvData.totalCollateralAssets, _ltvData.collateralAsset)
            : _ltvData.totalCollateralAssets;

        // if no oracle is set, assume price 1
        debtValue = address(_ltvData.debtOracle) != address(0)
            ? _ltvData.debtOracle.quote(_ltvData.debtAssets, _ltvData.debtAsset)
            : _ltvData.debtAssets;
    }

    /// @dev Calculates LTV for user. It is used in core logic. Non-view function is needed in case the oracle
    ///      has to write some data to storage to protect ie. from read re-entracy like in curve pools.
    /// @return ltv Loan-to-Value
    /// @return lt liquidation threshold
    /// @return maxLtv maximum Loan-to-Value
    function getLtv(
        ISiloConfig.ConfigData memory _configData0,
        ISiloConfig.ConfigData memory _configData1,
        address _borrower,
        ISilo.OracleType _oracleType,
        ISilo.AccrueInterestInMemory _accrueInMemory
    ) internal view returns (uint256 ltv, uint256 lt, uint256 maxLtv) {
        LtvData memory ltvData =
            getAssetsDataForLtvCalculations(_configData0, _configData1, _borrower, _oracleType, _accrueInMemory);

        lt = ltvData.ltInBP;
        maxLtv = ltvData.maxLtv;

        if (ltvData.debtAssets == 0) return (ltv, lt, maxLtv);

        (uint256 debtValue, uint256 collateralValue) = getPositionValues(ltvData);

        ltv = debtValue * _PRECISION_DECIMALS / collateralValue;
    }

    function isSolvent(
        ISiloConfig.ConfigData memory _configData0,
        ISiloConfig.ConfigData memory _configData1,
        address _borrower,
        ISilo.AccrueInterestInMemory _accrueInMemory
    ) internal view returns (bool) {
        (uint256 ltv, uint256 lt,) =
            getLtv(_configData0, _configData1, _borrower, ISilo.OracleType.Solvency, _accrueInMemory);

        return ltv < lt;
    }

    function isBelowMaxLtv(
        ISiloConfig.ConfigData memory _configData0,
        ISiloConfig.ConfigData memory _configData1,
        address _borrower,
        ISilo.AccrueInterestInMemory _accrueInMemory
    ) internal view returns (bool) {
        (uint256 ltv,, uint256 maxLTV) =
            getLtv(_configData0, _configData1, _borrower, ISilo.OracleType.MaxLtv, _accrueInMemory);

        return ltv < maxLTV;
    }
}
