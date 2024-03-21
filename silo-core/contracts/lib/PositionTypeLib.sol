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
import {SiloERC4626Lib} from "./SiloERC4626Lib.sol"; //circular dependency
import {SiloStdLib} from "./SiloStdLib.sol";
import {SiloMathLib} from "./SiloMathLib.sol";
import {TypesLib} from "./TypesLib.sol";

library PositionTypeLib {
    using MathUpgradeable for uint256;

    uint256 internal constant _PRECISION_DECIMALS = 1e18;

    function adjustConfigsAfterPositionDiscovery(
        ISiloConfig.ConfigData memory _currentConfig,
        ISiloConfig.ConfigData memory _otherConfig,
        uint256 _positionType
    )
        internal
        view
        returns (ISiloConfig.ConfigData memory collateralConfig, ISiloConfig.ConfigData memory debtConfig)
    {
        return _positionType == TypesLib.POSITION_TYPE_ONE_TOKEN
            ? (_currentConfig, _currentConfig)
            : (_otherConfig, _currentConfig);
    }

    /// @dev it detects position type for max borrow method, however we need to check two tokens max as well
    /// and pick the highest value of this two, because if method detects, that there is a way to have one-token
    /// position, it does not check, if there is also the way to have two-tokens position, if we can borrow more
    /// using two-tokens position and borrower will use higher amount then allowed for on-token position, two-token
    /// position iwll be created
    /// @notice this method should be called only when there is no debt
    /// @return positionType detected position type
    /// @return maxAssets max borrow amount for `positionType`
    function detectPositionTypeForMaxBorrow(
        ISiloConfig.ConfigData memory _siloConfig,
        ISiloConfig.ConfigData memory _otherSiloConfig,
        ISilo.AccrueInterestInMemory _accrueInMemory,
        address _borrower
    )
        internal
        view
        returns (uint256 positionType, uint256 maxAssets)
    {
        (uint256 positionType, uint256 maxAssets, uint256 sumOfCollateralAssets) = _detectPositionType(
            _siloConfig,
            _otherSiloConfig,
            _accrueInMemory,
            _borrower,
            // this is case where we can do "fast borrow", TODO we will require transfer TO silo here!
            1 // TODO we can use max deposit constant here _siloConfig.maxLtv
        );

        if (positionType != TypesLib.POSITION_TYPE_UNKNOWN) {
            return (positionType, maxAssets);
        }

        maxAssets = sumOfCollateralAssets * _siloConfig.maxLtv / _PRECISION_DECIMALS; // rounding down
        positionType = maxAssets != 0 ? TypesLib.POSITION_TYPE_ONE_TOKEN : TypesLib.POSITION_TYPE_TWO_TOKENS;
    }

    /// @dev we need to detect only when we have two deposits and no debt
    /// @return oneTokenLtv LTV calculated for one-token position, otherwise zero
    function detectPositionTypeForFirstBorrow(
        ISiloConfig.ConfigData memory _siloConfig,
        ISiloConfig.ConfigData memory _otherSiloConfig,
        ISilo.AccrueInterestInMemory _accrueInMemory,
        address _borrower,
        uint256 _assetsToBorrow
    )
        internal
        view
        returns (uint256 positionType, uint256 oneTokenLtv)
    {
        if (_assetsToBorrow == 0) return (TypesLib.POSITION_TYPE_UNKNOWN, 0);

        (uint256 positionType, uint256 oneTokenLtv, uint256 sumOfCollateralAssets) = _detectPositionType(
            _siloConfig,
            _otherSiloConfig,
            _accrueInMemory,
            _borrower,
            // this is case where we can do "fast borrow", TODO we will require transfer TO silo here!
            _siloConfig.lt
        );

        if (positionType != TypesLib.POSITION_TYPE_UNKNOWN) {
            return (positionType, oneTokenLtv);
        }

        oneTokenLtv = _assetsToBorrow.mulDiv(_PRECISION_DECIMALS, sumOfCollateralAssets, MathUpgradeable.Rounding.Up);

        // here we calculating for borrow, so we using LT, not maxLtv
        positionType = oneTokenLtv <= _siloConfig.lt
            ? TypesLib.POSITION_TYPE_ONE_TOKEN
            : TypesLib.POSITION_TYPE_TWO_TOKENS;
    }

    /// @dev we need to detect only when we have two deposits and no debt
    /// @param _valueForCase there is one case, where we need specific value for max borrow or LTV
    /// @return oneTokenLtv LTV calculated for one-token position, otherwise zero
    function _detectPositionType(
        ISiloConfig.ConfigData memory _siloConfig,
        ISiloConfig.ConfigData memory _otherSiloConfig,
        ISilo.AccrueInterestInMemory _accrueInMemory,
        address _borrower,
        address _assetsToBorrow,
        uint256 _valueForCase
    )
        private
        view
        returns (uint256 positionType, uint256 valueForCase, uint256 sumOfCollateralAssets)
    {
        uint256 borrowerProtectedShareBalance = IShareToken(_siloConfig.protectedShareToken).balanceOf(_borrower);
        uint256 borrowerCollateralShareBalance = IShareToken(_siloConfig.collateralShareToken).balanceOf(_borrower);
        uint256 otherProtectedShareBalance = IShareToken(_otherSiloConfig.protectedShareToken).balanceOf(_borrower);
        uint256 otherCollateralShareBalance = IShareToken(_otherSiloConfig.collateralShareToken).balanceOf(_borrower);

        if (borrowerProtectedShareBalance == 0 && borrowerCollateralShareBalance == 0) {
            return otherProtectedShareBalance == 0 && otherCollateralShareBalance == 0
                ? (TypesLib.POSITION_TYPE_ONE_TOKEN, _valueForCase)
                : (TypesLib.POSITION_TYPE_TWO_TOKENS, 0);
        } else if (otherProtectedShareBalance == 0 && otherCollateralShareBalance == 0) {
            return (TypesLib.POSITION_TYPE_TWO_TOKENS, 0);
        }

        // at this point we know we do have collateral in both silos

        uint256 totalCollateralAssets;
        uint256 totalProtectedAssets;

        if (borrowerProtectedShareBalance != 0 && borrowerCollateralShareBalance != 0 && !_accrueInMemory) {
            (totalCollateralAssets, totalProtectedAssets) = ISilo(_siloConfig.silo).getCollateralAndProtectedAssets();
        } else if (borrowerProtectedShareBalance != 0) {
            totalProtectedAssets = ISilo(_siloConfig.silo).total(ISilo.AssetType.Protected);
        } else if (borrowerCollateralShareBalance != 0 && !_accrueInMemory) {
            totalCollateralAssets = ISilo(_siloConfig.silo).getCollateralAssets();
        }

        uint256 borrowerProtectedAssets;

        if (borrowerProtectedShareBalance != 0) {
            borrowerProtectedAssets = SiloMathLib.convertToAssets(
                borrowerProtectedShareBalance,
                totalProtectedAssets,
                IShareToken(_siloConfig.protectedShareToken).totalSupply(),
                MathUpgradeable.Rounding.Down,
                ISilo.AssetType.Protected
            );
        }

        uint256 borrowerCollateralAssets;

        if (borrowerCollateralShareBalance != 0) {
            if (_accrueInMemory == ISilo.AccrueInterestInMemory.Yes) {
                totalCollateralAssets = SiloStdLib.getTotalCollateralAssetsWithInterest(
                    _siloConfig.silo,
                    _siloConfig.interestRateModel,
                    _siloConfig.daoFee,
                    _siloConfig.deployerFee
                );
            }

            borrowerCollateralAssets = SiloMathLib.convertToAssets(
                borrowerCollateralShareBalance,
                totalCollateralAssets,
                IShareToken(_siloConfig.collateralShareToken).totalSupply(),
                MathUpgradeable.Rounding.Down,
                ISilo.AssetType.Collateral
            );
        }

        uint256 sumOfCollateralAssets;
        // safe because we adding same token, so it is under same total supply, unless interest sky rockets, but then
        // ltv/max will be smaller
        unchecked { sumOfCollateralAssets = borrowerProtectedAssets + borrowerCollateralAssets; }

        // position type is still unknown
    }
}
