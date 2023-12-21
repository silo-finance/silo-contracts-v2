// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {MathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";

import {ISiloOracle} from "../interfaces/ISiloOracle.sol";
import {ISiloLiquidation} from "../interfaces/ISiloLiquidation.sol";
import {SiloStdLib, ISiloConfig, IShareToken, ISilo} from "./SiloStdLib.sol";
import {SiloERC4626Lib} from "./SiloERC4626Lib.sol";
import {SiloLiquidationLib} from "./SiloLiquidationLib.sol";
import {SiloMathLib} from "./SiloMathLib.sol";

import {console} from "forge-std/console.sol";

library SiloSolvencyLib {
    using MathUpgradeable for uint256;

    struct LtvData {
        ISiloOracle collateralOracle;
        ISiloOracle debtOracle;
        uint256 borrowerProtectedAssets;
        uint256 borrowerCollateralAssets;
        uint256 borrowerDebtAssets;
    }

    uint256 internal constant _PRECISION_DECIMALS = 1e18;
    uint256 internal constant _INFINITY = type(uint256).max;

    /// @dev check if config was given in correct order
    /// @return orderCorrect TRUE means that order is correct OR `_borrower` has no debt and we can not really tell
    function validConfigOrder(
        address _collateralConfigDebtShareToken,
        address _debtConfigDebtShareToken,
        address _borrower
    ) external view returns (bool orderCorrect) {
        uint256 debtShareTokenBalance = IShareToken(_debtConfigDebtShareToken).balanceOf(_borrower);

        return
            debtShareTokenBalance == 0 ? IShareToken(_collateralConfigDebtShareToken).balanceOf(_borrower) == 0 : true;
    }

    /// @notice Determines if a borrower is solvent based on the Loan-to-Value (LTV) ratio
    /// @param _collateralConfig Configuration data for the collateral
    /// @param _debtConfig Configuration data for the debt
    /// @param _borrower Address of the borrower to check solvency for
    /// @param _accrueInMemory Determines whether or not to consider un-accrued interest in calculations
    /// @return True if the borrower is solvent, false otherwise
    function isSolvent(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower,
        ISilo.AccrueInterestInMemory _accrueInMemory,
        uint256 debtShareBalance
    ) external view returns (bool) {
        uint256 ltv = getLtv(
            _collateralConfig, _debtConfig, _borrower, ISilo.OracleType.Solvency, _accrueInMemory, debtShareBalance
        );

        return ltv <= _collateralConfig.lt;
    }

    /// @notice Determines if a borrower's Loan-to-Value (LTV) ratio is below the maximum allowed LTV
    /// @param _collateralConfig Configuration data for the collateral
    /// @param _debtConfig Configuration data for the debt
    /// @param _borrower Address of the borrower to check against max LTV
    /// @param _accrueInMemory Determines whether or not to consider un-accrued interest in calculations
    /// @return True if the borrower's LTV is below the maximum, false otherwise
    function isBelowMaxLtv(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower,
        ISilo.AccrueInterestInMemory _accrueInMemory
    ) external view returns (bool) {
        uint256 debtShareBalance = IShareToken(_debtConfig.debtShareToken).balanceOf(_borrower);

        uint256 ltv = getLtv(
            _collateralConfig, _debtConfig, _borrower, ISilo.OracleType.MaxLtv, _accrueInMemory, debtShareBalance
        );

        console.log("[isBelowMaxLtv] ltv", ltv);

        return ltv <= _collateralConfig.maxLtv;
    }

    /// @notice Calculates the Loan-to-Value (LTV) ratio based on provided collateral and debt data
    /// @dev calculation never reverts, if there is revert, then it is because of oracle
    /// @param _ltvData Data structure containing relevant information to calculate LTV
    /// @param _collateralToken Address of the collateral token
    /// @param _debtToken Address of the debt token
    /// @return sumOfBorrowerCollateralValue Total value of borrower's collateral
    /// @return totalBorrowerDebtValue Total debt value for the borrower
    /// @return ltvInDp Calculated LTV in 18 decimal precision
    function calculateLtv(SiloSolvencyLib.LtvData memory _ltvData, address _collateralToken, address _debtToken)
        internal
        view
        returns (uint256 sumOfBorrowerCollateralValue, uint256 totalBorrowerDebtValue, uint256 ltvInDp)
    {
        (
            sumOfBorrowerCollateralValue, totalBorrowerDebtValue
        ) = getPositionValues(_ltvData, _collateralToken, _debtToken);

        console.log("[calculateLtv] sumOfBorrowerCollateralValue", sumOfBorrowerCollateralValue);
        console.log("[calculateLtv] totalBorrowerDebtValue", totalBorrowerDebtValue);

        if (sumOfBorrowerCollateralValue == 0 && totalBorrowerDebtValue == 0) {
            return (0, 0, 0);
        } else if (sumOfBorrowerCollateralValue == 0) {
            ltvInDp = _INFINITY;
        } else {
            console.log("[calculateLtv] %s * %s / %s", totalBorrowerDebtValue, _PRECISION_DECIMALS, sumOfBorrowerCollateralValue);

            ltvInDp = totalBorrowerDebtValue.mulDiv(_PRECISION_DECIMALS, sumOfBorrowerCollateralValue, MathUpgradeable.Rounding.Up);
            console.log("[calculateLtv] ltvInDp", ltvInDp);
//            ltvInDp = SiloMathLib.preciseDiv(totalBorrowerDebtValue, _PRECISION_DECIMALS, sumOfBorrowerCollateralValue);
//            console.log("[calculateLtv] ltvInDp precise!!", ltvInDp);

        }
    }

    /// @notice Retrieves assets data required for LTV calculations
    /// @param _collateralConfig Configuration data for the collateral
    /// @param _debtConfig Configuration data for the debt
    /// @param _borrower Address of the borrower whose LTV data is to be calculated
    /// @param _oracleType Specifies whether to use the MaxLTV or Solvency oracle type for calculations
    /// @param _accrueInMemory Determines whether or not to consider un-accrued interest in calculations
    /// @param _debtShareBalanceCached Cached value of debt share balance for the borrower. If debt shares of
    /// `_borrower` is unknown, simply pass `0`.
    /// @return ltvData Data structure containing necessary data to compute LTV
    function getAssetsDataForLtvCalculations( // solhint-disable-line function-max-lines
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower,
        ISilo.OracleType _oracleType,
        ISilo.AccrueInterestInMemory _accrueInMemory,
        uint256 _debtShareBalanceCached
    ) internal view returns (LtvData memory ltvData) {
        // When calculating maxLtv, use maxLtv oracle.
        (ltvData.collateralOracle, ltvData.debtOracle) = _oracleType == ISilo.OracleType.MaxLtv
            ? (ISiloOracle(_collateralConfig.maxLtvOracle), ISiloOracle(_debtConfig.maxLtvOracle))
            : (ISiloOracle(_collateralConfig.solvencyOracle), ISiloOracle(_debtConfig.solvencyOracle));

        uint256 totalShares;
        uint256 shares;

        (shares, totalShares) = SiloStdLib.getSharesAndTotalSupply(
            _collateralConfig.protectedShareToken, _borrower, 0 /* no cache */
        );

        (
            uint256 totalCollateralAssets, uint256 totalProtectedAssets
        ) = ISilo(_collateralConfig.silo).getCollateralAndProtectedAssets();

        ltvData.borrowerProtectedAssets = SiloMathLib.convertToAssets(
            shares, totalProtectedAssets, totalShares, MathUpgradeable.Rounding.Down, ISilo.AssetType.Protected
        );

        (shares, totalShares) = SiloStdLib.getSharesAndTotalSupply(
            _collateralConfig.collateralShareToken, _borrower, 0 /* no cache */
        );

        totalCollateralAssets = _accrueInMemory == ISilo.AccrueInterestInMemory.Yes
            ? SiloStdLib.getTotalCollateralAssetsWithInterest(
                _collateralConfig.silo,
                _collateralConfig.interestRateModel,
                _collateralConfig.daoFee,
                _collateralConfig.deployerFee
            )
            : totalCollateralAssets;

        ltvData.borrowerCollateralAssets = SiloMathLib.convertToAssets(
            shares, totalCollateralAssets, totalShares, MathUpgradeable.Rounding.Down, ISilo.AssetType.Collateral
        );

        (shares, totalShares) = SiloStdLib.getSharesAndTotalSupply(
            _debtConfig.debtShareToken, _borrower, _debtShareBalanceCached
        );

        uint256 totalDebtAssets = _accrueInMemory == ISilo.AccrueInterestInMemory.Yes
            ? SiloStdLib.getTotalDebtAssetsWithInterest(_debtConfig.silo, _debtConfig.interestRateModel)
            : ISilo(_debtConfig.silo).getDebtAssets();

        // BORROW value -> to assets -> UP
        ltvData.borrowerDebtAssets = SiloMathLib.convertToAssets(
            shares, totalDebtAssets, totalShares, MathUpgradeable.Rounding.Up, ISilo.AssetType.Debt
        );

        console.log("[getAssetsDataForLtvCalculations] shares", shares);
        console.log("[getAssetsDataForLtvCalculations] totalShares", totalShares);
        console.log("[getAssetsDataForLtvCalculations] ltvData.borrowerDebtAssets", ltvData.borrowerDebtAssets);
    }

    /// @notice Computes the value of collateral and debt positions based on given LTV data and asset addresses
    /// @param _ltvData Data structure containing the assets data required for LTV calculations
    /// @param _collateralAsset Address of the collateral asset
    /// @param _debtAsset Address of the debt asset
    /// @return sumOfCollateralValue Total value of collateral assets considering both protected and regular collateral
    /// assets
    /// @return debtValue Total value of debt assets
    function getPositionValues(LtvData memory _ltvData, address _collateralAsset, address _debtAsset)
        internal
        view
        returns (uint256 sumOfCollateralValue, uint256 debtValue)
    {
        uint256 sumOfCollateralAssets;
        // safe because we adding same token, so it is under same total supply
        unchecked { sumOfCollateralAssets = _ltvData.borrowerProtectedAssets + _ltvData.borrowerCollateralAssets; }

        if (sumOfCollateralAssets != 0) {
            // if no oracle is set, assume price 1, we should also not set oracle for quote token
            sumOfCollateralValue = address(_ltvData.collateralOracle) != address(0)
                ? _ltvData.collateralOracle.quote(sumOfCollateralAssets, _collateralAsset)
                : sumOfCollateralAssets;
        }

        if (_ltvData.borrowerDebtAssets != 0) {
            // if no oracle is set, assume price 1, we should also not set oracle for quote token
            debtValue = address(_ltvData.debtOracle) != address(0)
                ? _ltvData.debtOracle.quote(_ltvData.borrowerDebtAssets, _debtAsset)
                : _ltvData.borrowerDebtAssets;
        }
    }

    /// @notice Calculates the Loan-To-Value (LTV) ratio for a given borrower
    /// @param _collateralConfig Configuration data related to the collateral asset
    /// @param _debtConfig Configuration data related to the debt asset
    /// @param _borrower Address of the borrower whose LTV is to be computed
    /// @param _oracleType Oracle type to use for fetching the asset prices
    /// @param _accrueInMemory Determines whether or not to consider un-accrued interest in calculations
    /// @return ltvInDp The computed LTV ratio in 18 decimals precision
    function getLtv(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower,
        ISilo.OracleType _oracleType,
        ISilo.AccrueInterestInMemory _accrueInMemory,
        uint256 _debtShareBalance
    ) internal view returns (uint256 ltvInDp) {
        if (_debtShareBalance == 0) return 0;

        LtvData memory ltvData = getAssetsDataForLtvCalculations(
            _collateralConfig, _debtConfig, _borrower, _oracleType, _accrueInMemory, _debtShareBalance
        );

        if (ltvData.borrowerDebtAssets == 0) return 0;

        (,, ltvInDp) = calculateLtv(ltvData, _collateralConfig.token, _debtConfig.token);
    }
}
