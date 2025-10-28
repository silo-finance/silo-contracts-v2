// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IERC20} from "openzeppelin5/interfaces/IERC20.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";
import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";
import {IGaugeHookReceiver, IHookReceiver} from "silo-core/contracts/interfaces/IGaugeHookReceiver.sol";
import {PartialLiquidationLib} from "silo-core/contracts/hooks/liquidation/lib/PartialLiquidationLib.sol";
import {RepayActionLib} from "silo-core/contracts/hooks/liquidation/lib/RepayActionLib.sol";

import {SiloMathLib} from "silo-core/contracts/lib/SiloMathLib.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {Rounding} from "silo-core/contracts/lib/Rounding.sol";
import {RevertLib} from "silo-core/contracts/lib/RevertLib.sol";
import {CallBeforeQuoteLib} from "silo-core/contracts/lib/CallBeforeQuoteLib.sol";

import {PartialLiquidationExecLib} from "silo-core/contracts/hooks/liquidation/lib/PartialLiquidationExecLib.sol";
import {TransientReentrancy} from "silo-core/contracts/hooks/_common/TransientReentrancy.sol";
import {BaseHookReceiver} from "silo-core/contracts/hooks/_common/BaseHookReceiver.sol";

/// @title PartialLiquidation module for executing liquidations
/// @dev if we need additional hook functionality, this contract should be included as parent
abstract contract PartialLiquidationByDefaulting is TransientReentrancy, BaseHookReceiver, IPartialLiquidation {
    using SafeERC20 for IERC20;
    using Hook for uint24;
    using CallBeforeQuoteLib for ISiloConfig.ConfigData;

    /// @dev The portion of total liquidation fee proceeds allocated to the keeper. Expressed in 18 decimals.
    /// For example, liquidation fee is 10% (0.1e18), and keeper fee is 20% (0.2e18),
    /// then 2% liquidation fee goes to the keeper and 8% goes to the protocol.
    uint256 public KEEPER_FEE;

    struct CallParams {
        uint256 collateralShares;
        uint256 protectedShares;
        uint256 withdrawAssetsFromCollateralTotal;
        uint256 withdrawAssetsFromCollateralForKeeper;
        uint256 withdrawAssetsFromCollateralForLenders;
        uint256 withdrawAssetsFromProtectedTotal;
        uint256 withdrawAssetsFromProtectedForKeeper;
        uint256 withdrawAssetsFromProtectedForLenders;
        bytes4 customError;
    }

    function __PartialLiquidationByDefaulting_init(uint256 _keeperFee) // solhint-disable-line func-name-mixedcase
        internal
        onlyInitializing
        virtual
    {
        require(_keeperFee <= 1e18, "Invalid keeper fee");
        KEEPER_FEE = _keeperFee;
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
            params.withdrawAssetsFromCollateralTotal, params.withdrawAssetsFromProtectedTotal, repayDebtAssets, params.customError
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
            params.withdrawAssetsFromCollateralTotal,
            collateralConfig.liquidationFee
        );

        (params.withdrawAssetsFromProtectedForKeeper, params.withdrawAssetsFromProtectedForLenders) = getKeeperAndLenderAssetsSplit(
            params.withdrawAssetsFromProtectedTotal,
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

        siloConfigCached.turnOffReentrancyProtection();

        // settle debt without transferring tokens to silo, by defaulting on debt repayment

        bytes memory input = abi.encodeWithSelector(this.repayDebtByDefaulting.selector, repayDebtAssets, _borrower);

        ISilo(debtConfig.silo).callOnBehalfOfSilo({
            _target: address(this),
            _value: 0,
            _callType: ISilo.CallType.Delegatecall,
            _input: input
        });

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

    function getKeeperAndLenderAssetsSplit(uint256 withdrawAssetsFromCollateralTotal, uint256 _liquidationFee)
        public
        view
        virtual
        returns (uint256 withdrawAssetsFromCollateralForKeeper, uint256 withdrawAssetsFromCollateralForLenders)
    {
        // TODO: test for 0 and 1 wei results to make sure keeper cannot drain all proceeds using some kind of 1 wei rounding attack loop
        withdrawAssetsFromCollateralForKeeper = withdrawAssetsFromCollateralTotal
            * (_liquidationFee * KEEPER_FEE / PartialLiquidationLib._PRECISION_DECIMALS) // effective fee to keeper
            / (PartialLiquidationLib._PRECISION_DECIMALS + _liquidationFee); // adjust for fee-inclusive amount, 100% + liquidationFee
        withdrawAssetsFromCollateralForLenders = withdrawAssetsFromCollateralTotal - withdrawAssetsFromCollateralForKeeper;
    }

    function maxLiquidationByDefaulting(address _borrower)
        external
        view
        virtual
        returns (uint256 collateralToLiquidate, uint256 debtToRepay, bool sTokenRequired)
    {
        return PartialLiquidationExecLib.maxLiquidation(siloConfig, _borrower);
    }

    function repayDebtByDefaulting(uint256 _assets, address _borrower)
        external
        virtual
        returns (uint256 shares)
    {
        uint256 assets;

        (assets, shares) = RepayActionLib.repay({
            _assets: _assets,
            _shares: 0,
            _borrower: _borrower,
            _repayer: msg.sender
        });

        emit ISilo.Repay(msg.sender, _borrower, assets, shares);
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

        require(address(controllerCollateral) != address(0), "No controller for collateral");

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

    function _fetchConfigs(
        ISiloConfig _siloConfigCached,
        address _collateralAsset,
        address _debtAsset,
        address _borrower
    )
        internal
        virtual
        returns (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        )
    {
        (collateralConfig, debtConfig) = _siloConfigCached.getConfigsForSolvency(_borrower);

        require(debtConfig.silo != address(0), UserIsSolvent());
        require(_collateralAsset == collateralConfig.token, UnexpectedCollateralToken());
        require(_debtAsset == debtConfig.token, UnexpectedDebtToken());

        ISilo(debtConfig.silo).accrueInterest();

        if (collateralConfig.silo != debtConfig.silo) {
            ISilo(collateralConfig.silo).accrueInterest();
            collateralConfig.callSolvencyOracleBeforeQuote();
            debtConfig.callSolvencyOracleBeforeQuote();
        }
    }

    function _callShareTokenForwardTransferNoChecks(
        address _silo,
        address _borrower,
        address _receiver,
        uint256 _withdrawAssets,
        address _shareToken,
        ISilo.AssetType _assetType
    ) internal virtual returns (uint256 shares) {
        if (_withdrawAssets == 0) return 0;
        
        shares = SiloMathLib.convertToShares(
            _withdrawAssets,
            ISilo(_silo).getTotalAssetsStorage(_assetType),
            IShareToken(_shareToken).totalSupply(),
            Rounding.LIQUIDATE_TO_SHARES,
            ISilo.AssetType(_assetType)
        );

        if (shares == 0) return 0;

        IShareToken(_shareToken).forwardTransferFromNoChecks(_borrower, _receiver, shares);
    }
}
