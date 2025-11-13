// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Math} from "openzeppelin5/utils/math/Math.sol";
import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";

import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";
import {IGaugeHookReceiver, IHookReceiver} from "silo-core/contracts/interfaces/IGaugeHookReceiver.sol";
import {IPartialLiquidationByDefaulting} from "silo-core/contracts/interfaces/IPartialLiquidationByDefaulting.sol";

import {SiloStorageLib} from "silo-core/contracts/lib/SiloStorageLib.sol";
import {PartialLiquidationLib} from "silo-core/contracts/hooks/liquidation/lib/PartialLiquidationLib.sol";

import {
    PartialLiquidation,
    Rounding,
    SiloMathLib,
    ISiloConfig,
    ISilo,
    IShareToken,
    PartialLiquidationExecLib,
    RevertLib,
    CallBeforeQuoteLib
} from "../liquidation/PartialLiquidation.sol";
import {DefaultingSiloLogic} from "./DefaultingSiloLogic.sol";
import {Whitelist} from "silo-core/contracts/hooks/_common/Whitelist.sol";

// solhint-disable ordering

/// @title PartialLiquidation module for executing liquidations
/// @dev if we need additional hook functionality, this contract should be included as parent
abstract contract PartialLiquidationByDefaulting is IPartialLiquidationByDefaulting, PartialLiquidation, Whitelist {
    using CallBeforeQuoteLib for ISiloConfig.ConfigData;

    /// @dev The portion of total liquidation fee proceeds allocated to the keeper. Expressed in 18 decimals.
    /// For example, liquidation fee is 10% (0.1e18), and keeper fee is 20% (0.2e18),
    /// then 2% liquidation fee goes to the keeper and 8% goes to the protocol.
    uint256 public constant KEEPER_FEE = 0.2e18;

    /// @dev Address of the DefaultingSiloLogic contract used by Silo for delegate calls
    address public immutable LIQUIDATION_LOGIC;

    /// @dev Additional liquidation threshold (LT) margin applied during defaulting liquidations
    /// to give priority to traditional liquidations over defaulting ones. Expressed in 18 decimals.
    uint256 public constant LT_MARGIN_FOR_DEFAULTING = 0.25e18;

    constructor() {
        LIQUIDATION_LOGIC = address(new DefaultingSiloLogic());
    }

    function __PartialLiquidationByDefaulting_init(address _owner) // solhint-disable-line func-name-mixedcase
        internal
        onlyInitializing
        virtual
    {
        __Whitelist_init(_owner);

        (address silo0, address silo1) = siloConfig.getSilos();

        validateDefaultingCollateral(silo0, silo1);
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

        (ISiloConfig.ConfigData memory collateralConfig, ISiloConfig.ConfigData memory debtConfig) =
            _fetchConfigs(siloConfigCached, _borrower);

        collateralConfig.lt += LT_MARGIN_FOR_DEFAULTING;

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
        (
            params.collateralSharesTotal,
            params.collateralSharesForKeeper,
            params.collateralSharesForLenders
        ) = getKeeperAndLenderSharesSplit({
            _silo: collateralConfig.silo,
            _shareToken: collateralConfig.silo,
            _liquidationFee: collateralConfig.liquidationFee,
            _withdrawAssets: params.withdrawAssetsFromCollateral,
            _assetType: ISilo.AssetType.Collateral
        });

        (
            params.protectedSharesTotal,
            params.protectedSharesForKeeper,
            params.protectedSharesForLenders
        ) = getKeeperAndLenderSharesSplit({
            _silo: collateralConfig.silo,
            _shareToken: collateralConfig.protectedShareToken,
            _liquidationFee: collateralConfig.liquidationFee,
            _withdrawAssets: params.withdrawAssetsFromProtected,
            _assetType: ISilo.AssetType.Protected
        });

        _liquidateByDistributingCollateral({
            _borrower: _borrower,
            _debtSilo: debtConfig.silo,
            _shareToken: collateralConfig.collateralShareToken,
            _withdrawSharesForLenders: params.collateralSharesForLenders,
            _withdrawSharesForKeeper: params.collateralSharesForKeeper
        });

        _liquidateByDistributingCollateral({
            _borrower: _borrower,
            _debtSilo: debtConfig.silo,
            _shareToken: collateralConfig.protectedShareToken,
            _withdrawSharesForLenders: params.protectedSharesForLenders,
            _withdrawSharesForKeeper: params.protectedSharesForKeeper
        });

        // calculate total withdrawn collateral

        if (params.collateralSharesTotal != 0) {
            withdrawCollateral =
                ISilo(collateralConfig.silo).previewRedeem(params.collateralSharesTotal, ISilo.CollateralType.Collateral);
        }

        if (params.protectedSharesTotal != 0) {
            withdrawCollateral +=
                ISilo(collateralConfig.silo).previewRedeem(params.protectedSharesTotal, ISilo.CollateralType.Protected);
        }

        _deductDefaultedDebtFromCollateral(debtConfig.silo, repayDebtAssets);

        siloConfigCached.turnOffReentrancyProtection();

        // settle debt without transferring tokens to silo, by defaulting on debt repayment

        _repayDebtByDefaulting(debtConfig.silo, repayDebtAssets, _borrower);

        // TODO: test that if repay reverts, all reverts

        emit LiquidationCall(msg.sender, debtConfig.silo, _borrower, repayDebtAssets, withdrawCollateral, true);
    }

    function getKeeperAndLenderSharesSplit(
        address _silo,
        address _shareToken,
        uint256 _liquidationFee,
        uint256 _withdrawAssets,
        ISilo.AssetType _assetType
    ) public view virtual returns (uint256 totalShares, uint256 keeperShares, uint256 lendersShares) {
        if (_withdrawAssets == 0) return (0, 0, 0);

        totalShares = SiloMathLib.convertToShares({
            _assets: _withdrawAssets,
            _totalAssets: ISilo(_silo).getTotalAssetsStorage(_assetType),
            _totalShares: IShareToken(_shareToken).totalSupply(),
            _rounding: Rounding.LIQUIDATE_TO_SHARES,
            _assetType: _assetType
        });

        // TODO: test for 0 and 1 wei results to make sure keeper cannot drain all proceeds 
        // using some kind of 1 wei rounding attack loop

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
        keeperShares = Math.mulDiv(
            totalShares,
            _liquidationFee * KEEPER_FEE,
            PartialLiquidationLib._PRECISION_DECIMALS,
            Math.Rounding.Floor
        ) / (PartialLiquidationLib._PRECISION_DECIMALS + _liquidationFee);

        lendersShares = totalShares - keeperShares;
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

    function validateDefaultingCollateral(address _silo0, address _silo1)
        public
        view
        virtual
    {
        ISiloConfig.ConfigData memory config0 = siloConfig.getConfig(_silo0);
        ISiloConfig.ConfigData memory config1 = siloConfig.getConfig(_silo1);

        require(config0.maxLtv == 0 || config1.maxLtv == 0, InvalidLT());
    }

    function _deductDefaultedDebtFromCollateral(address _silo, uint256 _assetsToRepay) internal virtual {
        bytes memory input =
            abi.encodeWithSelector(DefaultingSiloLogic.deductDefaultedDebtFromCollateral.selector, _assetsToRepay);

        ISilo(_silo).callOnBehalfOfSilo({
            _target: LIQUIDATION_LOGIC,
            _value: 0,
            _callType: ISilo.CallType.Delegatecall,
            _input: input
        });
    }

    function _repayDebtByDefaulting(address _silo, uint256 _assets, address _borrower) internal virtual {
        bytes memory input =
            abi.encodeWithSelector(DefaultingSiloLogic.repayDebtByDefaulting.selector, _assets, _borrower);

        ISilo(_silo).callOnBehalfOfSilo({
            _target: LIQUIDATION_LOGIC,
            _value: 0,
            _callType: ISilo.CallType.Delegatecall,
            _input: input
        });
    }

    function _liquidateByDistributingCollateral(
        address _borrower,
        address _debtSilo,
        address _shareToken,
        uint256 _withdrawSharesForLenders,
        uint256 _withdrawSharesForKeeper
    ) internal virtual {
        ISiloIncentivesController controllerCollateral = validateControllerForCollateral(_debtSilo);

        // distribute collateral shares to lenders
        if (_withdrawSharesForLenders > 0) {
            IShareToken(_shareToken).forwardTransferFromNoChecks(_borrower, address(controllerCollateral), _withdrawSharesForLenders);
            controllerCollateral.immediateDistribution(_shareToken, SafeCast.toUint104(_withdrawSharesForLenders));
        }

        // distribute collateral shares to keeper
        if (_withdrawSharesForKeeper > 0) {
            IShareToken(_shareToken).forwardTransferFromNoChecks(_borrower, msg.sender, _withdrawSharesForKeeper);
        }
    }

    function _fetchConfigs(ISiloConfig _siloConfigCached, address _borrower)
        internal
        virtual
        returns (ISiloConfig.ConfigData memory collateralConfig, ISiloConfig.ConfigData memory debtConfig)
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
