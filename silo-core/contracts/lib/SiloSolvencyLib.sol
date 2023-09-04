// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {MathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";

import {ISiloOracle} from "../interfaces/ISiloOracle.sol";
import {SiloStdLib, ISiloConfig, IShareToken, ISilo} from "./SiloStdLib.sol";
import {SiloERC4626Lib} from "./SiloERC4626Lib.sol";

// solhint-disable ordering

library SiloSolvencyLib {
    /// @dev Silo has two separate oracles for ltv and lt calcualtions. Lt oracle is optional. Ltv oracle can also
    ///      be optional if asset is used as denominator.
    enum OracleType {
        Ltv,
        Lt
    }

    /// @dev Static value will use values and amount directly from storage. Dynamic value will add interest accrued
    ///      from the last timestamp on the fly.
    enum InterestRateType {
        Static,
        Dynamic
    }

    uint256 internal constant _PRECISION_DECIMALS = 1e18;

    struct LtvData {
        address debtAsset;
        address collateralAsset;
        ISiloOracle debtOracle;
        ISiloOracle collateralOracle;
        uint256 debtAssets;
        uint256 totalCollateralAssets;
        bool isToken0Collateral;
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
    function getAssetsData(
        ISiloConfig.ConfigData memory _configData,
        address _borrower,
        OracleType _oracleType,
        InterestRateType _interestRateType
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

            // If LTV is needed for solvency, ltOracle should be used. If ltOracle is not set, fallback to ltvOracle.
            ltvData.debtOracle = _oracleType == OracleType.Lt && _configData.ltOracle0 != address(0)
                ? ISiloOracle(_configData.ltOracle0)
                : ISiloOracle(_configData.ltvOracle0);
            ltvData.collateralOracle = _oracleType == OracleType.Lt && _configData.ltOracle1 != address(0)
                ? ISiloOracle(_configData.ltOracle1)
                : ISiloOracle(_configData.ltvOracle1);
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

                // If LTV is needed for solvency, ltOracle should be used. If ltOracle is not set,
                // fallback to ltvOracle.
                ltvData.debtOracle = _oracleType == OracleType.Lt && _configData.ltOracle1 != address(0)
                    ? ISiloOracle(_configData.ltOracle1)
                    : ISiloOracle(_configData.ltvOracle1);
                ltvData.collateralOracle = _oracleType == OracleType.Lt && _configData.ltOracle0 != address(0)
                    ? ISiloOracle(_configData.ltOracle0)
                    : ISiloOracle(_configData.ltvOracle0);

                ltvData.isToken0Collateral = true;
            } else {
                return ltvData; // nothing borrowed
            }
        }

        /// @dev Round up so borrower has more to repay. Always round in favor of the protocol.
        ltvData.debtAssets = SiloERC4626Lib.convertToAssets(
            ltvCache.debtShareTokenBalance,
            /// @dev amountWithInterest is not needed for core LTV calculations because accrueInterest was just called
            ///      and storage data is fresh.
            _interestRateType == InterestRateType.Dynamic
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
                /// @dev amountWithInterest is not needed for core LTV calculations because accrueInterest is called
                _interestRateType == InterestRateType.Dynamic
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

    /// @dev Returns LTV and other data. Method is implemented as a view function for off-chain use. It's easier
    ///      for off-chain software to use view functions. It helps avoids weird behaviours. It uses quoteView
    ///      from oracle which cannot change state.
    /// @return ltv Loan-to-Value
    /// @return isToken0Collateral true if token0 is collateral
    /// @return debtValue value of debt quoted by oracle
    /// @return collateralValue value of collateral quoted by oracle
    /// @return totalCollateralAssets sum of protected and collateral assets
    function getLtvAndData(ISiloConfig.ConfigData memory _configData, address _borrower)
        internal
        view
        returns (
            uint256 ltv,
            bool isToken0Collateral,
            uint256 debtValue,
            uint256 collateralValue,
            uint256 totalCollateralAssets
        )
    {
        LtvData memory ltvData = getAssetsData(_configData, _borrower, OracleType.Lt, InterestRateType.Dynamic);

        isToken0Collateral = ltvData.isToken0Collateral;
        totalCollateralAssets = ltvData.totalCollateralAssets;

        if (ltvData.debtAssets == 0) {
            return (ltv, isToken0Collateral, debtValue, collateralValue, totalCollateralAssets);
        }

        // if no oracle is set, assume price 1
        debtValue = address(ltvData.debtOracle) != address(0)
            ? ltvData.debtOracle.quoteView(ltvData.debtAssets, ltvData.debtAsset)
            : ltvData.debtAssets;

        // if no oracle is set, assume price 1
        collateralValue = address(ltvData.collateralOracle) != address(0)
            ? ltvData.collateralOracle.quoteView(ltvData.totalCollateralAssets, ltvData.collateralAsset)
            : ltvData.totalCollateralAssets;

        ltv = debtValue * _PRECISION_DECIMALS / collateralValue;
    }

    /// @dev Calculates LTV for user. It is used in core logic. Non-view function is needed in case the oracle
    ///      has to write some data to storage to protect ie. from read re-entracy like in curve pools.
    /// @return ltv Loan-to-Value
    /// @return isToken0Collateral true if token0 is collateral
    function getLtv(ISiloConfig.ConfigData memory _configData, address _borrower)
        internal
        returns (uint256 ltv, bool isToken0Collateral)
    {
        LtvData memory ltvData = getAssetsData(_configData, _borrower, OracleType.Lt, InterestRateType.Static);

        isToken0Collateral = ltvData.isToken0Collateral;

        if (ltvData.debtAssets == 0) return (ltv, isToken0Collateral);

        // if no oracle is set, assume price 1
        uint256 debtValue = address(ltvData.debtOracle) != address(0)
            ? ltvData.debtOracle.quote(ltvData.debtAssets, ltvData.debtAsset)
            : ltvData.debtAssets;

        // if no oracle is set, assume price 1
        uint256 collateralValue = address(ltvData.collateralOracle) != address(0)
            ? ltvData.collateralOracle.quote(ltvData.totalCollateralAssets, ltvData.collateralAsset)
            : ltvData.totalCollateralAssets;

        ltv = debtValue * _PRECISION_DECIMALS / collateralValue;
    }

    function isSolvent(ISiloConfig.ConfigData memory _configData, address _borrower) internal returns (bool) {
        (uint256 ltv, bool isToken0Collateral) = getLtv(_configData, _borrower);

        uint256 lt = isToken0Collateral ? _configData.lt0 : _configData.lt1;

        return ltv <= lt;
    }

    function isSolvent(ISiloConfig _config, address _borrower) internal returns (bool) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        return isSolvent(configData, _borrower);
    }

    function isSolventWithInterestAccrue(ISiloConfig _config, address _borrower) internal view returns (bool) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        (uint256 ltv, bool isToken0Collateral,,,) = getLtvAndData(configData, _borrower);

        uint256 lt = isToken0Collateral ? configData.lt0 : configData.lt1;

        return ltv <= lt;
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
