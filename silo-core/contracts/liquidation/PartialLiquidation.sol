// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {ISilo, ILiquidationProcess} from "../interfaces/ISilo.sol";
import {IPartialLiquidation} from "../interfaces/IPartialLiquidation.sol";
import {ILiquidationModule} from "../interfaces/ILiquidationModule.sol";
import {ISiloOracle} from "../interfaces/ISiloOracle.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";

import {SiloSolvencyLib2} from "../lib/SiloSolvencyLib2.sol";
import {PartialLiquidationExecLib} from "./lib/PartialLiquidationExecLib.sol";


/// @title PartialLiquidation module for executing liquidations
contract PartialLiquidation is ILiquidationModule, IPartialLiquidation, ReentrancyGuardUpgradeable {
    /// @inheritdoc IPartialLiquidation
    function liquidationCall( // solhint-disable-line function-max-lines
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
        returns (uint256 withdrawCollateral, uint256 repayDebtAssets)
    {
        (ISiloConfig.ConfigData memory debtConfig, ISiloConfig.ConfigData memory collateralConfig) =
            ISilo(_siloWithDebt).config().getConfigs(_siloWithDebt);

        if (_collateralAsset != collateralConfig.token) revert UnexpectedCollateralToken();
        if (_debtAsset != debtConfig.token) revert UnexpectedDebtToken();

        ISilo(_siloWithDebt).accrueInterest();
        ISilo(debtConfig.otherSilo).accrueInterest();

        if (collateralConfig.callBeforeQuote) {
            ISiloOracle(collateralConfig.solvencyOracle).beforeQuote(collateralConfig.token);
        }

        if (debtConfig.callBeforeQuote) {
            ISiloOracle(debtConfig.solvencyOracle).beforeQuote(debtConfig.token);
        }

        bool selfLiquidation = _borrower == msg.sender;
        uint256 withdrawAssetsFromCollateral;
        uint256 withdrawAssetsFromProtected;

        (
            withdrawAssetsFromCollateral, withdrawAssetsFromProtected, repayDebtAssets
        ) = PartialLiquidationExecLib.getExactLiquidationAmounts(
            collateralConfig,
            debtConfig,
            _borrower,
            _debtToCover,
            selfLiquidation ? 0 : collateralConfig.liquidationFee,
            selfLiquidation
        );

        if (repayDebtAssets == 0) revert NoDebtToCover();
        // this two value were split from total collateral to withdraw, so we will not overflow
        unchecked { withdrawCollateral = withdrawAssetsFromCollateral + withdrawAssetsFromProtected; }

        emit LiquidationCall(msg.sender, _receiveSToken);
        ILiquidationProcess(_siloWithDebt).liquidationRepay(repayDebtAssets, _borrower, msg.sender);

        ILiquidationProcess(debtConfig.otherSilo).withdrawCollateralsToLiquidator(
            withdrawAssetsFromCollateral, withdrawAssetsFromProtected, _borrower, msg.sender, _receiveSToken
        );
    }

    /// @inheritdoc ILiquidationModule
    function maxLiquidation(address _siloWithDebt, address _borrower)
        external
        view
        virtual
        returns (uint256 collateralToLiquidate, uint256 debtToRepay)
    {
        return PartialLiquidationExecLib.maxLiquidation(ISilo(_siloWithDebt), _borrower);
    }

    /// @inheritdoc ILiquidationModule
    function isSolvent(
        ISiloConfig.ConfigData calldata _collateralConfig,
        ISiloConfig.ConfigData calldata _debtConfig,
        address _borrower,
        ISilo.AccrueInterestInMemory _accrueInMemory
    ) external view virtual returns (bool) {
        uint256 debtShareBalance = IShareToken(_debtConfig.debtShareToken).balanceOf(_borrower);
        return isSolvent(_collateralConfig, _debtConfig, _borrower, _accrueInMemory, debtShareBalance);
    }

    /// @inheritdoc ILiquidationModule
    function isSolvent(
        ISiloConfig.ConfigData calldata _collateralConfig,
        ISiloConfig.ConfigData calldata _debtConfig,
        address _borrower,
        ISilo.AccrueInterestInMemory _accrueInMemory,
        uint256 debtShareBalance
    ) public view virtual returns (bool) {
        return SiloSolvencyLib2.isSolvent(_collateralConfig, _debtConfig, _borrower, _accrueInMemory, debtShareBalance);
    }

    /// @inheritdoc ILiquidationModule
    function isBelowMaxLtv(
        ISiloConfig.ConfigData calldata _collateralConfig,
        ISiloConfig.ConfigData calldata _debtConfig,
        address _borrower,
        ISilo.AccrueInterestInMemory _accrueInMemory
    ) external view virtual returns (bool) {
        return SiloSolvencyLib2.isBelowMaxLtv(_collateralConfig, _debtConfig, _borrower, _accrueInMemory);
    }

    /// @notice Calculates the Loan-To-Value (LTV) ratio for a given borrower
    /// @param _collateralConfig Configuration data related to the collateral asset
    /// @param _debtConfig Configuration data related to the debt asset
    /// @param _borrower Address of the borrower whose LTV is to be computed
    /// @param _oracleType Oracle type to use for fetching the asset prices
    /// @param _accrueInMemory Determines whether or not to consider un-accrued interest in calculations
    /// @return ltvInDp The computed LTV ratio in 18 decimals precision
    function getLtv(
        ISiloConfig.ConfigData calldata _collateralConfig,
        ISiloConfig.ConfigData calldata _debtConfig,
        address _borrower,
        ISilo.OracleType _oracleType,
        ISilo.AccrueInterestInMemory _accrueInMemory,
        uint256 _debtShareBalance
    ) external view virtual returns (uint256 ltvInDp) {
        return SiloSolvencyLib2.getLtv(
            _collateralConfig, _debtConfig, _borrower, _oracleType, _accrueInMemory, _debtShareBalance
        );
    }
}
