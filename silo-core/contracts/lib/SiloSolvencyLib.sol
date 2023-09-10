// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {MathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";

import {ISiloOracle} from "../interfaces/ISiloOracle.sol";
import {SiloStdLib, ISiloConfig, IShareToken, ISilo} from "./SiloStdLib.sol";
import {SiloERC4626Lib} from "./SiloERC4626Lib.sol";

library SiloSolvencyLib {
    struct LtvData {
        address debtAsset;
        address collateralAsset;
        ISiloOracle debtOracle;
        ISiloOracle collateralOracle;
        uint256 debtAssets;
        uint256 totalCollateralAssets;
        uint256 lt;
        uint256 maxLtv;
    }

    uint256 internal constant _PRECISION_DECIMALS = 1e18;

    function convertToAssetsWtihInterest(
        ISiloConfig.ConfigData memory _configData,
        address _borrower,
        ISilo.AccrueInterestInMemory _accrueInMemory,
        ISilo.AssetType _assetType,
        MathUpgradeable.Rounding _rounding
    ) internal view returns (uint256 assets) {
        IShareToken shareToken = SiloStdLib.findShareToken(_configData, _assetType);
        uint256 shareBalance = shareToken.balanceOf(_borrower);

        if (shareBalance == 0) return 0;

        assets = SiloERC4626Lib.convertToAssets(
            shareBalance,
            /// @dev amountWithInterest is not needed for core LTV calculations because accrueInterest was just called
            ///      and storage data is fresh.
            _accrueInMemory == ISilo.AccrueInterestInMemory.Yes
                ? SiloStdLib.amountWithInterest(
                    _configData.token, ISilo(_configData.silo).getDebtAssets(), _configData.interestRateModel
                )
                : ISilo(_configData.silo).getDebtAssets(),
            shareToken.totalSupply(),
            _rounding
        );
    }

    function getAssetsDataForLtvCalculations(
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

            if (debtShareTokenBalance == 0) {
                // nothing borrowed
                return ltvData;
            } else {
                // configs in wrong order, reverse order
                ISiloConfig.ConfigData memory _tempConfig;

                _tempConfig = _debtConfig;
                _debtConfig = _collateralConfig;
                _collateralConfig = _tempConfig;
            }
        }

        ltvData.debtAsset = _debtConfig.token;
        ltvData.collateralAsset = _collateralConfig.token;
        ltvData.lt = _collateralConfig.lt;
        ltvData.maxLtv = _collateralConfig.maxLtv;

        // If LTV is needed for solvency, ltOracle should be used. If ltOracle is not set, fallback to ltvOracle.
        ltvData.debtOracle = _oracleType == ISilo.OracleType.MaxLtv && _debtConfig.maxLtvOracle != address(0)
            ? ISiloOracle(_debtConfig.maxLtvOracle)
            : ISiloOracle(_debtConfig.solvencyOracle);
        ltvData.collateralOracle = _oracleType == ISilo.OracleType.MaxLtv
            && _collateralConfig.maxLtvOracle != address(0)
            ? ISiloOracle(_collateralConfig.maxLtvOracle)
            : ISiloOracle(_collateralConfig.solvencyOracle);

        ltvData.debtAssets = convertToAssetsWtihInterest(
            _debtConfig, _borrower, _accrueInMemory, ISilo.AssetType.Debt, MathUpgradeable.Rounding.Up
        );

        ltvData.totalCollateralAssets = convertToAssetsWtihInterest(
            _collateralConfig, _borrower, _accrueInMemory, ISilo.AssetType.Protected, MathUpgradeable.Rounding.Down
        );

        ltvData.totalCollateralAssets += convertToAssetsWtihInterest(
            _collateralConfig, _borrower, _accrueInMemory, ISilo.AssetType.Collateral, MathUpgradeable.Rounding.Down
        );
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

        lt = ltvData.lt;
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
