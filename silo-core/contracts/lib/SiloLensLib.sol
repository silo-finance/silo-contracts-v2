// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ISilo} from "../interfaces/ISilo.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";

import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";

import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";
import {SiloMathLib} from "./SiloMathLib.sol";

library SiloLensLib {
    uint256 internal constant _PRECISION_DECIMALS = 1e18;

    function getRawLiquidity(ISilo _silo) internal view returns (uint256 liquidity) {
        return SiloMathLib.liquidity(
            _silo.getTotalAssetsStorage(ISilo.AssetType.Collateral),
            _silo.getTotalAssetsStorage(ISilo.AssetType.Debt)
        );
    }

    function getMaxLtv(ISilo _silo) internal view returns (uint256 maxLtv) {
        maxLtv = _silo.config().getConfig(address(_silo)).maxLtv;
    }

    function getLt(ISilo _silo) internal view returns (uint256 lt) {
        lt = _silo.config().getConfig(address(_silo)).lt;
    }

    function getInterestRateModel(ISilo _silo) internal view returns (address irm) {
        irm = _silo.config().getConfig(address(_silo)).interestRateModel;
    }

    function getBorrowAPR(ISilo _silo) internal view returns (uint256 borrowAPR) {
        IInterestRateModel model = IInterestRateModel(getInterestRateModel(_silo));
        uint256 interestRateTimestamp = _silo.utilizationData().interestRateTimestamp;

        // adding 1s, so in case we accrued interest for current block it will not return 0.
        uint256 rcomp = model.getCompoundInterestRate(address(_silo), block.timestamp + 1);
        uint256 deltaT = (block.timestamp + 1) - interestRateTimestamp;

        borrowAPR = 356 days * rcomp / deltaT;
    }

    function getDepositAPR(ISilo _silo) internal view returns (uint256 depositAPR) {
        uint256 collateralAssets = _silo.getCollateralAssets();

        if (collateralAssets == 0) {
            return 0;
        }

        ISiloConfig.ConfigData memory cfg = _silo.config().getConfig((address(_silo)));
        depositAPR = getBorrowAPR(_silo) * _silo.getDebtAssets() / collateralAssets;
        depositAPR = depositAPR * (_PRECISION_DECIMALS - cfg.daoFee - cfg.deployerFee) / _PRECISION_DECIMALS;
    }

    function getLtv(ISilo _silo, address _borrower) internal view returns (uint256 ltv) {
        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        ) = _silo.config().getConfigsForSolvency(_borrower);

        if (debtConfig.silo != address(0)) {
            ltv = SiloSolvencyLib.getLtv(
                collateralConfig,
                debtConfig,
                _borrower,
                ISilo.OracleType.Solvency,
                ISilo.AccrueInterestInMemory.Yes,
                IShareToken(debtConfig.debtShareToken).balanceOf(_borrower)
            );
        }
    }

    function hasPosition(ISiloConfig _siloConfig, address _borrower) internal view returns (bool has) {
        (address silo0, address silo1) = _siloConfig.getSilos();
        ISiloConfig.ConfigData memory cfg0 = _siloConfig.getConfig(silo0);
        ISiloConfig.ConfigData memory cfg1 = _siloConfig.getConfig(silo1);

        if (IShareToken(cfg0.collateralShareToken).balanceOf(_borrower) != 0) return true;
        if (IShareToken(cfg0.protectedShareToken).balanceOf(_borrower) != 0) return true;
        if (IShareToken(cfg1.collateralShareToken).balanceOf(_borrower) != 0) return true;
        if (IShareToken(cfg1.protectedShareToken).balanceOf(_borrower) != 0) return true;

        if (IShareToken(cfg0.debtShareToken).balanceOf(_borrower) != 0) return true;
        if (IShareToken(cfg1.debtShareToken).balanceOf(_borrower) != 0) return true;

        return false;
      }

    function inDebt(ISiloConfig _siloConfig, address _borrower) internal view returns (bool has) {
        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        ) = _siloConfig.getConfigsForSolvency(_borrower);

        has = debtConfig.debtShareToken != address(0)
            && IShareToken(debtConfig.debtShareToken).balanceOf(_borrower) != 0;
    }

    function collateralBalanceOfUnderlying(ISilo _silo, address _borrower)
        internal
        view
        returns (uint256 borrowerCollateral)
    {
        (
            address protectedShareToken, address collateralShareToken,
        ) = _silo.config().getShareTokens(address(_silo));

        uint256 protectedShareBalance = IShareToken(protectedShareToken).balanceOf(_borrower);
        uint256 collateralShareBalance = IShareToken(collateralShareToken).balanceOf(_borrower);

        if (protectedShareBalance != 0) {
            borrowerCollateral = _silo.previewRedeem(protectedShareBalance, ISilo.CollateralType.Protected);
        }

        if (collateralShareBalance != 0) {
            borrowerCollateral += _silo.previewRedeem(collateralShareBalance, ISilo.CollateralType.Collateral);
        }
    }

    function totalBorrowShare(ISilo _silo) internal view returns (uint256) {
        (,, address debtShareToken) = _silo.config().getShareTokens(address(_silo));
        return IShareToken(debtShareToken).totalSupply();
    }

    function borrowShare(ISilo _silo, address _borrower) external view returns (uint256) {
        (,, address debtShareToken) = _silo.config().getShareTokens(address(_silo));
        return IShareToken(debtShareToken).balanceOf(_borrower);
    }

    function calculateValues(ISiloConfig _siloConfig, address _borrower)
        internal
        view
        returns (uint256 sumOfBorrowerCollateralValue, uint256 totalBorrowerDebtValue)
    {
        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        ) = _siloConfig.getConfigsForSolvency(_borrower);

        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.getAssetsDataForLtvCalculations(
            collateralConfig,
            debtConfig,
            _borrower,
            ISilo.OracleType.Solvency,
            ISilo.AccrueInterestInMemory.Yes,
            IShareToken(debtConfig.debtShareToken).balanceOf(_borrower)
        );

        (
            sumOfBorrowerCollateralValue, totalBorrowerDebtValue,
        ) = SiloSolvencyLib.calculateLtv(ltvData, collateralConfig.token, debtConfig.token);
    }
}
