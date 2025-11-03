// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Math} from "openzeppelin5/utils/math/Math.sol";
import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";

import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";
import {IGaugeHookReceiver, IHookReceiver} from "silo-core/contracts/interfaces/IGaugeHookReceiver.sol";
import {IPartialLiquidationByDefaulting} from "silo-core/contracts/interfaces/IPartialLiquidationByDefaulting.sol";

import {SiloStorageLib} from "silo-core/contracts/lib/SiloStorageLib.sol";
import {PartialLiquidationLib} from "silo-core/contracts/hooks/liquidation/lib/PartialLiquidationLib.sol";

import {PartialLiquidation, ISiloConfig, ISilo, IShareToken, PartialLiquidationExecLib, RevertLib, CallBeforeQuoteLib} from "../liquidation/PartialLiquidation.sol";
import {DefaultingSiloLogic} from "./DefaultingSiloLogic.sol";
import {Whitelist} from "silo-core/contracts/hooks/_common/Whitelist.sol";

/// @title PartialLiquidation module for executing liquidations
/// @dev if we need additional hook functionality, this contract should be included as parent
abstract contract PartialLiquidationByDefaulting is IPartialLiquidationByDefaulting, PartialLiquidation, Whitelist {
    using CallBeforeQuoteLib for ISiloConfig.ConfigData;

    /// @dev The portion of total liquidation fee proceeds allocated to the keeper. Expressed in 18 decimals.
    /// For example, liquidation fee is 10% (0.1e18), and keeper fee is 20% (0.2e18),
    /// then 2% liquidation fee goes to the keeper and 8% goes to the protocol.
    uint256 public constant KEEPER_FEE = 0.2e18;

    address public defaultingCollateral;

    address public immutable liquidationLogicAddress;

    constructor() {
        liquidationLogicAddress = address(new DefaultingSiloLogic());
    }

    function __PartialLiquidationByDefaulting_init(address _owner, address _defaultingCollateral) // solhint-disable-line func-name-mixedcase
        internal
        onlyInitializing
        virtual
    {
        __Whitelist_init(_owner);

        (address silo0, address silo1) = siloConfig.getSilos();

        validateControllerForCollateral(silo0);
        validateControllerForCollateral(silo1);

        defaultingCollateral = _defaultingCollateral;
    }

    function liquidationCallByDefaulting(address _borrower) // solhint-disable-line function-max-lines, code-complexity
        external
        virtual
        nonReentrant
        onlyAllowedOrPublic
        returns (uint256 withdrawCollateral, uint256 repayDebtAssets)
    {
        ISiloConfig siloConfigCached = siloConfig;

        require(address(siloConfigCached) != address(0), EmptySiloConfig());

        siloConfigCached.turnOnReentrancyProtection();

        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        ) = _fetchConfigs(siloConfigCached, _borrower);

        // defaulting can be only done for one (predefined) collateral to avoid creating cascading liquidations
        // on the other silo
        require(collateralConfig.token == defaultingCollateral, CollateralNotSupportedForDefaulting());

        collateralConfig.lt += 0.1e18; // require higher LT for defaulting liquidations

        CallParams memory params;

        (
            params.withdrawAssetsFromCollateral, params.withdrawAssetsFromProtected, repayDebtAssets, params.customError
        ) = PartialLiquidationExecLib.getExactLiquidationAmounts({
            _collateralConfig: collateralConfig,
            _debtConfig: debtConfig,
            _user: _borrower,
            _maxDebtToCover: type(uint256).max,
            _liquidationFee: collateralConfig.liquidationFee
        });

        RevertLib.revertIfError(params.customError);
        
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

        params.collateralShares = _liquidateByDistributingCollateral(
            collateralConfig.silo,
            _borrower,
            params.withdrawAssetsFromCollateralForLenders,
            debtConfig.silo,
            collateralConfig.collateralShareToken,
            ISilo.AssetType.Collateral
        );

        params.protectedShares = _liquidateByDistributingCollateral(
            collateralConfig.silo,
            _borrower,
            params.withdrawAssetsFromProtectedForLenders,
            debtConfig.silo,
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

        _deductDefaultedDebtFromCollateral(debtConfig.silo, repayDebtAssets);

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
        if (withdrawAssetsFromCollateral == 0) return (0, 0);

        // TODO: test for 0 and 1 wei results to make sure keeper cannot drain all proceeds using some kind of 1 wei rounding attack loop

        // c - collateral
        // wc - withdrawCollateral
        // f - liquidation fee
        // kf - keeper Fee
        // kw - keeper withdrawal
        // D - normalization divider

        // c + c * f = wc
        // c * (1 + f) = wc
        // c = wc / ( 1 + f)

        // kw =  c * f * kf => f * kf * wc / ( 1 + f) 

        // at the end we need to normalize, but we see we have only mul and div operations, so we can do
        // normalization at the end no problem, assuming D is our normalization Divider based on fees
        // decimals final pseudo code is:

        // kw = f * kf * wc / (1 + f) / D
        // kw = muldiv(f * kf, wc, (1 + f), Floor) / D
        withdrawAssetsFromCollateralForKeeper = Math.mulDiv(
            withdrawAssetsFromCollateral,
            _liquidationFee * KEEPER_FEE,
            PartialLiquidationLib._PRECISION_DECIMALS,
            Math.Rounding.Floor
        ) / (PartialLiquidationLib._PRECISION_DECIMALS + _liquidationFee);

        withdrawAssetsFromCollateralForLenders = withdrawAssetsFromCollateral - withdrawAssetsFromCollateralForKeeper;
    }

    function validateControllerForCollateral(address _silo)
        public
        view
        virtual
        returns (ISiloIncentivesController controllerCollateral)
    {
        (, address collateralShareToken,) = siloConfig.getShareTokens(_silo);
        controllerCollateral = IGaugeHookReceiver(address(this)).configuredGauges(IShareToken(collateralShareToken));
        require(address(controllerCollateral) != address(0), NoControllerForCollateral());
    }

    function _deductDefaultedDebtFromCollateral(address _silo, uint256 _assetsToRepay) internal virtual {
        bytes memory input = abi.encodeWithSelector(
            DefaultingSiloLogic.deductDefaultedDebtFromCollateral.selector,
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

    function _liquidateByDistributingCollateral(
        address _silo,
        address _borrower,
        uint256 _withdrawAssetsForLenders,
        address _debtSilo,
        address _collateralShareToken,
        ISilo.AssetType _assetType
    ) internal virtual returns (uint256 collateralShares) {
        ISiloIncentivesController controllerCollateral = validateControllerForCollateral(_debtSilo);

        collateralShares = _callShareTokenForwardTransferNoChecks(
            _silo,
            _borrower,
            address(controllerCollateral),
            _withdrawAssetsForLenders,
            _collateralShareToken,
            _assetType
        );

        if (collateralShares != 0) {
            controllerCollateral.immediateDistribution(_collateralShareToken, SafeCast.toUint104(collateralShares));
        }
    }

    function _fetchConfigs(ISiloConfig _siloConfigCached, address _borrower)
        internal
        virtual
        returns (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        )
    {
        (collateralConfig, debtConfig) = _siloConfigCached.getConfigsForSolvency(_borrower);

        require(debtConfig.silo != address(0), UserIsSolvent());

        ISilo(debtConfig.silo).accrueInterest();

        if (collateralConfig.silo != debtConfig.silo) {
            ISilo(collateralConfig.silo).accrueInterest();
            collateralConfig.callSolvencyOracleBeforeQuote();
            debtConfig.callSolvencyOracleBeforeQuote();
        }
    }
}
