// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";

import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";
import {IGaugeHookReceiver, IHookReceiver} from "silo-core/contracts/interfaces/IGaugeHookReceiver.sol";

import {SiloStorageLib} from "silo-core/contracts/lib/SiloStorageLib.sol";
import {PartialLiquidationLib} from "silo-core/contracts/hooks/liquidation/lib/PartialLiquidationLib.sol";

import {PartialLiquidation, ISiloConfig, ISilo, IShareToken, PartialLiquidationExecLib, RevertLib} from "../liquidation/PartialLiquidation.sol";
import {DefaultingSiloLogic} from "./DefaultingSiloLogic.sol";

/// @title PartialLiquidation module for executing liquidations
/// @dev if we need additional hook functionality, this contract should be included as parent
abstract contract PartialLiquidationByDefaulting is PartialLiquidation {

    /// @dev The portion of total liquidation fee proceeds allocated to the keeper. Expressed in 18 decimals.
    /// For example, liquidation fee is 10% (0.1e18), and keeper fee is 20% (0.2e18),
    /// then 2% liquidation fee goes to the keeper and 8% goes to the protocol.
    uint256 public constant KEEPER_FEE = 0.2e18;

    address public liquidationLogicAddress;

    error NoControllerForCollateral(address collateralShareToken);

    struct CallParams {
        uint256 collateralShares;
        uint256 protectedShares;
        uint256 withdrawAssetsFromCollateral;
        uint256 withdrawAssetsFromCollateralForKeeper;
        uint256 withdrawAssetsFromCollateralForLenders;
        uint256 withdrawAssetsFromProtected;
        uint256 withdrawAssetsFromProtectedForKeeper;
        uint256 withdrawAssetsFromProtectedForLenders;
        bytes4 customError;
    }

    function __PartialLiquidationByDefaulting_init() // solhint-disable-line func-name-mixedcase
        internal
        onlyInitializing
        virtual
    {
        liquidationLogicAddress = address(new DefaultingSiloLogic());

        (address silo0, address silo1) = siloConfig.getSilos();
        (, address collateralShareToken0,) = siloConfig.getShareTokens(silo0);
        (, address collateralShareToken1,) = siloConfig.getShareTokens(silo1);

        ISiloIncentivesController controllerCollateral0 = IGaugeHookReceiver(address(this)).configuredGauges(IShareToken(collateralShareToken0));
        ISiloIncentivesController controllerCollateral1 = IGaugeHookReceiver(address(this)).configuredGauges(IShareToken(collateralShareToken1));

        require(address(controllerCollateral0) != address(0), NoControllerForCollateral(collateralShareToken0));
        require(address(controllerCollateral1) != address(0), NoControllerForCollateral(collateralShareToken1));
    }

    function liquidationCallByDefaulting( // solhint-disable-line function-max-lines, code-complexity
        address _collateralAsset,
        address _debtAsset,
        address _borrower,
        uint256 _maxDebtToCover
    )
        external
        virtual
        nonReentrant
        returns (uint256 withdrawCollateral, uint256 repayDebtAssets)
    {
        ISiloConfig siloConfigCached = siloConfig;

        require(address(siloConfigCached) != address(0), EmptySiloConfig());
        require(_maxDebtToCover != 0, NoDebtToCover());

        siloConfigCached.turnOnReentrancyProtection();

        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        ) = _fetchConfigs(siloConfigCached, _collateralAsset, _debtAsset, _borrower);

        CallParams memory params;

        (
            params.withdrawAssetsFromCollateral, params.withdrawAssetsFromProtected, repayDebtAssets, params.customError
        ) = PartialLiquidationExecLib.getExactLiquidationAmounts(
            collateralConfig,
            debtConfig,
            _borrower,
            _maxDebtToCover,
            collateralConfig.liquidationFee
        );

        RevertLib.revertIfError(params.customError);

        // we do not allow dust so full liquidation is required
        require(repayDebtAssets <= _maxDebtToCover, FullLiquidationRequired());
        
        // calculate split between keeper and lenders
        (params.withdrawAssetsFromCollateralForKeeper, params.withdrawAssetsFromCollateralForLenders) = getKeeperAndLenderAssetsSplit(
            params.withdrawAssetsFromCollateral,
            collateralConfig.liquidationFee
        );

        (params.withdrawAssetsFromProtectedForKeeper, params.withdrawAssetsFromProtectedForLenders) = getKeeperAndLenderAssetsSplit(
            params.withdrawAssetsFromProtected,
            collateralConfig.liquidationFee
        );

        // transfer share tokens to incentive controller for distribution to lenders

        params.collateralShares = _defaultAndDistributeCollateral(
            collateralConfig.silo,
            _borrower,
            params.withdrawAssetsFromCollateralForLenders,
            debtConfig.collateralShareToken,
            collateralConfig.collateralShareToken,
            ISilo.AssetType.Collateral
        );

        params.protectedShares = _defaultAndDistributeCollateral(
            collateralConfig.silo,
            _borrower,
            params.withdrawAssetsFromProtectedForLenders,
            debtConfig.collateralShareToken,
            collateralConfig.protectedShareToken,
            ISilo.AssetType.Protected
        );

        // transfer keeper's rewards

        params.collateralShares += _callShareTokenForwardTransferNoChecks(
            collateralConfig.silo,
            _borrower,
            msg.sender,
            params.withdrawAssetsFromCollateralForKeeper,
            collateralConfig.collateralShareToken,
            ISilo.AssetType.Collateral
        );

        params.protectedShares += _callShareTokenForwardTransferNoChecks(
            collateralConfig.silo,
            _borrower,
            msg.sender,
            params.withdrawAssetsFromProtectedForKeeper,
            collateralConfig.protectedShareToken,
            ISilo.AssetType.Protected
        );

        _decreaseTotalCollateralAssets(debtConfig.silo, repayDebtAssets);

        siloConfigCached.turnOffReentrancyProtection();

        // settle debt without transferring tokens to silo, by defaulting on debt repayment

        _repayDebtByDefaulting(debtConfig.silo, repayDebtAssets, _borrower);

        // TODO: test that if repay reverts, all reverts

        if (params.collateralShares != 0) {
            withdrawCollateral = ISilo(collateralConfig.silo).previewRedeem(
                params.collateralShares,
                ISilo.CollateralType.Collateral
            );
        }

        if (params.protectedShares != 0) {
            unchecked {
                // protected and collateral values were split from total collateral to withdraw,
                // so we will not overflow when we sum them back, especially that on redeem, we rounding down
                withdrawCollateral += ISilo(collateralConfig.silo).previewRedeem(
                    params.protectedShares,
                    ISilo.CollateralType.Protected
                );
            }
        }

        emit LiquidationCall(
            msg.sender,
            debtConfig.silo,
            _borrower,
            repayDebtAssets,
            withdrawCollateral,
            true
        );
    }

    function getKeeperAndLenderAssetsSplit(uint256 withdrawAssetsFromCollateral, uint256 _liquidationFee)
        public
        view
        virtual
        returns (uint256 withdrawAssetsFromCollateralForKeeper, uint256 withdrawAssetsFromCollateralForLenders)
    {
        // TODO: test for 0 and 1 wei results to make sure keeper cannot drain all proceeds using some kind of 1 wei rounding attack loop
        withdrawAssetsFromCollateralForKeeper = withdrawAssetsFromCollateral
            * (_liquidationFee * KEEPER_FEE / PartialLiquidationLib._PRECISION_DECIMALS) // effective fee to keeper
            / (PartialLiquidationLib._PRECISION_DECIMALS + _liquidationFee); // adjust for fee-inclusive amount, 100% + liquidationFee
        withdrawAssetsFromCollateralForLenders = withdrawAssetsFromCollateral - withdrawAssetsFromCollateralForKeeper;
    }

    function _decreaseTotalCollateralAssets(address _silo, uint256 _assetsToRepay) internal virtual {
        bytes memory input = abi.encodeWithSelector(
            DefaultingSiloLogic.decreaseTotalCollateralAssets.selector,
            _assetsToRepay
        );

        ISilo(_silo).callOnBehalfOfSilo({
            _target: liquidationLogicAddress,
            _value: 0,
            _callType: ISilo.CallType.Delegatecall,
            _input: input
        });
    }

    function _repayDebtByDefaulting(address _silo, uint256 _assets, address _borrower) internal virtual {
        bytes memory input = abi.encodeWithSelector(
            DefaultingSiloLogic.repayDebtByDefaulting.selector,
            _assets,
            _borrower
        );

        ISilo(_silo).callOnBehalfOfSilo({
            _target: liquidationLogicAddress,
            _value: 0,
            _callType: ISilo.CallType.Delegatecall,
            _input: input
        });
    }

    function _defaultAndDistributeCollateral(
        address _silo,
        address _borrower,
        uint256 _withdrawAssetsForLenders,
        address _collateralShareTokenForDebt,
        address _collateralShareToken,
        ISilo.AssetType _assetType
    ) internal virtual returns (uint256 collateralShares) {
        ISiloIncentivesController controllerCollateral = IGaugeHookReceiver(address(this)).configuredGauges(IShareToken(_collateralShareTokenForDebt));

        require(address(controllerCollateral) != address(0), NoControllerForCollateral(_collateralShareTokenForDebt));

        collateralShares = _callShareTokenForwardTransferNoChecks(
            _silo,
            _borrower,
            address(controllerCollateral),
            _withdrawAssetsForLenders,
            _collateralShareToken,
            _assetType
        );

        controllerCollateral.immediateDistribution(_collateralShareToken, SafeCast.toUint104(collateralShares));
    }
}
