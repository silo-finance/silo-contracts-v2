// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {MathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";

import {ISiloOracle} from "../interfaces/ISiloOracle.sol";
import {ISiloLiquidation} from "../interfaces/ISiloLiquidation.sol";
import {SiloStdLib, ISiloConfig, IShareToken, ISilo} from "./SiloStdLib.sol";
import {SiloERC4626Lib} from "./SiloERC4626Lib.sol";
import {SiloLiquidationLib} from "./SiloLiquidationLib.sol";
import {SiloMathLib} from "./SiloMathLib.sol";

library SiloSolvencyLib {
    struct LtvData {
        ISiloOracle collateralOracle;
        ISiloOracle debtOracle;
        uint256 borrowerProtectedAssets;
        uint256 borrowerCollateralAssets;
        uint256 borrowerDebtAssets;
    }

    uint256 internal constant _PRECISION_DECIMALS = 1e18;
    uint256 internal constant _BASIS_POINTS = 1e4;


    function calculateLtv(
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
        ltvData.borrowerProtectedAssets =
            SiloMathLib.convertToAssets(shares, totalAssets, totalShares, MathUpgradeable.Rounding.Down);

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
        ltvData.borrowerCollateralAssets =
            SiloMathLib.convertToAssets(shares, totalAssets, totalShares, MathUpgradeable.Rounding.Down);

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

        ltvData.borrowerDebtAssets =
            SiloMathLib.convertToAssets(shares, totalAssets, totalShares, MathUpgradeable.Rounding.Up);
    }

    function getPositionValues(LtvData memory _ltvData, address _collateralAsset, address _debtAsset)
        internal
        view
        returns (uint256 collateralValue, uint256 debtValue)
    {
        uint256 totalCollateralAssets = _ltvData.borrowerProtectedAssets + _ltvData.borrowerCollateralAssets;
        // if no oracle is set, assume price 1
        collateralValue = address(_ltvData.collateralOracle) != address(0)
            ? _ltvData.collateralOracle.quote(totalCollateralAssets, _collateralAsset)
            : totalCollateralAssets;

        // if no oracle is set, assume price 1
        debtValue = address(_ltvData.debtOracle) != address(0)
            ? _ltvData.debtOracle.quote(_ltvData.borrowerDebtAssets, _debtAsset)
            : _ltvData.borrowerDebtAssets;
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

        if (ltvData.borrowerDebtAssets == 0) return 0;

        (ltv,,) = calculateLtv(ltvData, _collateralConfig.token, _debtConfig.token);
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
}
