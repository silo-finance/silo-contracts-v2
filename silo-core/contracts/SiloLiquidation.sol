// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {ISilo} from "./interfaces/ISilo.sol";
import {ISiloLiquidation} from "./interfaces/ISiloLiquidation.sol";
import {ISiloOracle} from "./interfaces/ISiloOracle.sol";
import {ISiloConfig} from "./interfaces/ISiloConfig.sol";

import {SiloLiquidationExecLib} from "./lib/SiloLiquidationExecLib.sol";

// Keep ERC4626 ordering
// solhint-disable ordering

/// @title SiloLiquidation module for executing liquidations
contract SiloLiquidation is ISiloLiquidation, ReentrancyGuardUpgradeable {
    /// @inheritdoc ISiloLiquidation
    function maxLiquidation(address _siloWithDebt, address _borrower)
        external
        view
        virtual
        returns (uint256 collateralToLiquidate, uint256 debtToRepay)
    {
        return SiloLiquidationExecLib.maxLiquidation(ISilo(_siloWithDebt), _borrower);
    }

    /// @inheritdoc ISiloLiquidation
    /// @dev it can be called on "debt silo" only
    /// @notice user can use this method to do self liquidation, it that case check for LT requirements will be ignored
    function liquidationCall(
        address _siloWithDebt,
        address _collateralAsset,
        address _debtAsset,
        address _borrower,
        uint256 _debtToCover,
        bool _receiveSToken
    )
        external
        virtual
        nonReentrant
        returns (uint256 withdrawAssetsFromCollateral, uint256 withdrawAssetsFromProtected, uint256 repayDebtAssets)
    {
        (ISiloConfig.ConfigData memory debtConfig, ISiloConfig.ConfigData memory collateralConfig) =
            ISilo(_siloWithDebt).config().getConfigs(_siloWithDebt);

        if (_collateralAsset != collateralConfig.token) revert UnexpectedCollateralToken();
        if (_debtAsset != debtConfig.token) revert UnexpectedDebtToken();

        // can we avoid?
        ISilo(_siloWithDebt).accrueInterest();
        ISilo(debtConfig.otherSilo).accrueInterest();

        if (collateralConfig.callBeforeQuote) {
            ISiloOracle(collateralConfig.solvencyOracle).beforeQuote(collateralConfig.token);
        }

        if (debtConfig.callBeforeQuote) {
            ISiloOracle(debtConfig.solvencyOracle).beforeQuote(debtConfig.token);
        }

        bool selfLiquidation = _borrower == msg.sender;

        (
            withdrawAssetsFromCollateral, withdrawAssetsFromProtected, repayDebtAssets
        ) = SiloLiquidationExecLib.getExactLiquidationAmounts(
            collateralConfig,
            debtConfig,
            _borrower,
            _debtToCover,
            selfLiquidation ? 0 : collateralConfig.liquidationFee,
            selfLiquidation
        );

        if (repayDebtAssets == 0) revert NoDebtToCover();

        emit LiquidationCall(msg.sender, _receiveSToken);
        ISilo(_siloWithDebt).repay(repayDebtAssets, _borrower, msg.sender);

        ISilo(debtConfig.otherSilo).withdrawCollateralsToLiquidator(
            withdrawAssetsFromCollateral, withdrawAssetsFromProtected, _borrower, msg.sender, _receiveSToken
        );
    }
//
//    /// @inheritdoc ISiloLiquidation
//    /// @dev it can be called on "debt silo" only
//    /// @notice user can use this method to do self liquidation, it that case check for LT requirements will be ignored
//    function liquidationPreview(
//        address _siloWithDebt,
//        address _collateralAsset,
//        address _debtAsset,
//        address _borrower,
//        uint256 _debtToCover,
//        bool _receiveSToken
//    ) external virtual view returns () {
//        (ISiloConfig.ConfigData memory debtConfig, ISiloConfig.ConfigData memory collateralConfig) =
//            ISilo(_siloWithDebt).config().getConfigs(_siloWithDebt);
//
//        if (_collateralAsset != collateralConfig.token) revert UnexpectedCollateralToken();
//        if (_debtAsset != debtConfig.token) revert UnexpectedDebtToken();
//
//        ISilo(_siloWithDebt).accrueInterest();
//        ISilo(debtConfig.otherSilo).accrueInterest();
//
//        if (collateralConfig.callBeforeQuote) {
//            ISiloOracle(collateralConfig.solvencyOracle).beforeQuote(collateralConfig.token);
//        }
//
//        if (debtConfig.callBeforeQuote) {
//            ISiloOracle(debtConfig.solvencyOracle).beforeQuote(debtConfig.token);
//        }
//
//        bool selfLiquidation = _borrower == msg.sender;
//
//        (
//            uint256 withdrawAssetsFromCollateral, uint256 withdrawAssetsFromProtected, uint256 repayDebtAssets
//        ) = SiloLiquidationExecLib.getExactLiquidationAmounts(
//            collateralConfig,
//            debtConfig,
//            _borrower,
//            _debtToCover,
//            selfLiquidation ? 0 : collateralConfig.liquidationFee,
//            selfLiquidation
//        );
//    }
}
