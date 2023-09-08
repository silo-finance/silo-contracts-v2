// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {MathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";

import {ISiloOracle} from "../interfaces/ISiloOracle.sol";
import {SiloStdLib, ISiloConfig, IShareToken, ISilo} from "./SiloStdLib.sol";
import {SiloERC4626Lib} from "./SiloERC4626Lib.sol";

// solhint-disable ordering

library SiloSolvencyLib {
    uint256 internal constant _PRECISION_DECIMALS = 1e18;

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

    struct LtvCache {
        ISilo debtSilo;
        ISilo collateralSilo;
        IShareToken debtShareToken;
        IShareToken protectedShareToken;
        IShareToken collateralShareToken;
        address debtInterestRateModel;
        address collateralInterestRateModel;
        uint256 debtShareTokenBalance;
        uint256 debtValue;
        uint256 collateralValue;
    }

    // solhint-disable-next-line function-max-lines
    function getAssetsDataForLtvCalculations(
        ISiloConfig.ConfigData memory _configData,
        address _borrower,
        ISilo.OracleType _oracleType,
        ISilo.AccrueInterestInMemory _accrueInMemory
    ) internal view returns (LtvData memory ltvData) {
        LtvCache memory ltvCache;
        uint256 debtShareToken0Balance = IShareToken(_configData.debtShareToken0).balanceOf(_borrower);

        if (debtShareToken0Balance != 0) {
            // borrowed token0, collateralized token1
            ltvCache.debtShareTokenBalance = debtShareToken0Balance;
            ltvCache.debtSilo = ISilo(_configData.silo0);
            ltvCache.debtInterestRateModel = _configData.interestRateModel0;
            ltvCache.debtShareToken = IShareToken(_configData.debtShareToken0);

            ltvCache.collateralSilo = ISilo(_configData.silo1);
            ltvCache.collateralInterestRateModel = _configData.interestRateModel1;
            ltvCache.protectedShareToken = IShareToken(_configData.protectedShareToken1);
            ltvCache.collateralShareToken = IShareToken(_configData.collateralShareToken1);

            ltvData.debtAsset = _configData.token0;
            ltvData.collateralAsset = _configData.token1;

            ltvData.lt = _configData.lt1;
            ltvData.maxLtv = _configData.maxLtv1;

            // If LTV is needed for solvency, ltOracle should be used. If ltOracle is not set, fallback to ltvOracle.
            ltvData.debtOracle = _oracleType == ISilo.OracleType.MaxLtv && _configData.maxLtvOracle0 != address(0)
                ? ISiloOracle(_configData.maxLtvOracle0)
                : ISiloOracle(_configData.solvencyOracle0);
            ltvData.collateralOracle = _oracleType == ISilo.OracleType.MaxLtv
                && _configData.maxLtvOracle1 != address(0)
                ? ISiloOracle(_configData.maxLtvOracle1)
                : ISiloOracle(_configData.solvencyOracle1);
        } else {
            uint256 debtShareToken1Balance = IShareToken(_configData.debtShareToken1).balanceOf(_borrower);

            if (debtShareToken1Balance != 0) {
                // borrowed token1, collateralized token0
                ltvCache.debtShareTokenBalance = debtShareToken1Balance;
                ltvCache.debtSilo = ISilo(_configData.silo1);
                ltvCache.debtInterestRateModel = _configData.interestRateModel1;
                ltvCache.debtShareToken = IShareToken(_configData.debtShareToken1);
                
                ltvCache.collateralSilo = ISilo(_configData.silo0);
                ltvCache.collateralInterestRateModel = _configData.interestRateModel0;
                ltvCache.protectedShareToken = IShareToken(_configData.protectedShareToken0);
                ltvCache.collateralShareToken = IShareToken(_configData.collateralShareToken0);

                ltvData.debtAsset = _configData.token1;
                ltvData.collateralAsset = _configData.token0;

                ltvData.lt = _configData.lt0;
                ltvData.maxLtv = _configData.maxLtv0;

                /// @dev If max ltv oracle is requested check if it is set because it's optional. If not, fallback to
                ///      solvency oracle.
                ltvData.debtOracle = _oracleType == ISilo.OracleType.MaxLtv && _configData.maxLtvOracle1 != address(0)
                    ? ISiloOracle(_configData.maxLtvOracle1)
                    : ISiloOracle(_configData.solvencyOracle1);
                ltvData.collateralOracle = _oracleType == ISilo.OracleType.MaxLtv
                    && _configData.maxLtvOracle0 != address(0)
                    ? ISiloOracle(_configData.maxLtvOracle0)
                    : ISiloOracle(_configData.solvencyOracle0);
            } else {
                return ltvData; // nothing borrowed
            }
        }

        /// @dev Round up so borrower has more to repay. Always round in favor of the protocol.
        ltvData.debtAssets = SiloERC4626Lib.convertToAssets(
            ltvCache.debtShareTokenBalance,
            /// @dev amountWithInterest is not needed for core LTV calculations because accrueInterest was just called
            ///      and storage data is fresh.
            _accrueInMemory == ISilo.AccrueInterestInMemory.Yes
                ? SiloStdLib.amountWithInterest(
                    ltvData.debtAsset, ltvCache.debtSilo.getDebtAssets(), ltvCache.debtInterestRateModel
                )
                : ltvCache.debtSilo.getDebtAssets(),
            ltvCache.debtShareToken.totalSupply(),
            MathUpgradeable.Rounding.Up
        );

        uint256 protectedBalance = ltvCache.protectedShareToken.balanceOf(_borrower);
        uint256 protectedAssets;

        if (protectedBalance != 0) {
            protectedAssets = SiloERC4626Lib.convertToAssets(
                protectedBalance,
                ltvCache.collateralSilo.getProtectedAssets(),
                ltvCache.protectedShareToken.totalSupply(),
                MathUpgradeable.Rounding.Down
            );
        }

        uint256 collateralBalance = ltvCache.collateralShareToken.balanceOf(_borrower);
        uint256 collateralAssets;

        if (collateralBalance != 0) {
            collateralAssets = SiloERC4626Lib.convertToAssets(
                collateralBalance,
                /// @dev amountWithInterest is not needed for core LTV calculations because accrueInterest was just
                ///      called and storage data is fresh.
                _accrueInMemory == ISilo.AccrueInterestInMemory.Yes
                    ? SiloStdLib.amountWithInterest(
                        ltvData.collateralAsset,
                        ltvCache.collateralSilo.getCollateralAssets(),
                        ltvCache.collateralInterestRateModel
                    )
                    : ltvCache.collateralSilo.getCollateralAssets(),
                ltvCache.collateralShareToken.totalSupply(),
                MathUpgradeable.Rounding.Down
            );
        }

        /// @dev sum of assets cannot be bigger than total supply which must fit in uint256
        unchecked {
            ltvData.totalCollateralAssets = protectedAssets + collateralAssets;
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
        ISiloConfig.ConfigData memory _configData,
        address _borrower,
        ISilo.OracleType _oracleType,
        ISilo.AccrueInterestInMemory _accrueInMemory
    ) internal view returns (uint256 ltv, uint256 lt, uint256 maxLtv) {
        LtvData memory ltvData = getAssetsDataForLtvCalculations(_configData, _borrower, _oracleType, _accrueInMemory);

        lt = ltvData.lt;
        maxLtv = ltvData.maxLtv;

        if (ltvData.debtAssets == 0) return (ltv, lt, maxLtv);

        (uint256 debtValue, uint256 collateralValue) = getPositionValues(ltvData);

        ltv = debtValue * _PRECISION_DECIMALS / collateralValue;
    }

    function isSolvent(
        ISiloConfig.ConfigData memory _configData,
        address _borrower,
        ISilo.AccrueInterestInMemory _accrueInMemory
    ) internal view returns (bool) {
        (uint256 ltv, uint256 lt,) = getLtv(_configData, _borrower, ISilo.OracleType.Solvency, _accrueInMemory);

        return ltv < lt;
    }

    function isBelowMaxLtv(
        ISiloConfig.ConfigData memory _configData,
        address _borrower,
        ISilo.AccrueInterestInMemory _accrueInMemory
    ) internal view returns (bool) {
        (uint256 ltv,, uint256 maxLTV) = getLtv(_configData, _borrower, ISilo.OracleType.MaxLtv, _accrueInMemory);

        return ltv < maxLTV;
    }

    function getMaxLtv(ISiloConfig _config) internal view returns (uint256) {
        (ISiloConfig.ConfigData memory configData, address asset) = _config.getConfigWithAsset(address(this));

        if (configData.token0 == asset) {
            return configData.maxLtv0;
        } else if (configData.token1 == asset) {
            return configData.maxLtv1;
        } else {
            revert ISilo.WrongToken();
        }
    }

    function getLt(ISiloConfig _config) internal view returns (uint256) {
        (ISiloConfig.ConfigData memory configData, address asset) = _config.getConfigWithAsset(address(this));

        if (configData.token0 == asset) {
            return configData.lt0;
        } else if (configData.token1 == asset) {
            return configData.lt1;
        } else {
            revert ISilo.WrongToken();
        }
    }
}
