// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";
import {IPendleMarketLike} from "silo-core/contracts/interfaces/IPendleMarketLike.sol";
import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";
import {IGaugeLike as IGauge} from "silo-core/contracts/interfaces/IGaugeLike.sol";
import {IPendleRewardsClaimer} from "silo-core/contracts/interfaces/IPendleRewardsClaimer.sol";
import {
    ISiloIncentivesControllerGetters
} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesControllerGetters.sol";

import {GaugeHookReceiver} from "silo-core/contracts/hooks/gauge/GaugeHookReceiver.sol";
import {PartialLiquidation} from "silo-core/contracts/hooks/liquidation/PartialLiquidation.sol";
import {BaseHookReceiver} from "silo-core/contracts/hooks/_common/BaseHookReceiver.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {ShareTokenLib} from "silo-core/contracts/lib/ShareTokenLib.sol";

/// @title PendleRewardsClaimer
/// @notice This hook allows to redeem rewards from Pendle for the silo.
contract PendleRewardsClaimer is GaugeHookReceiver, PartialLiquidation, IPendleRewardsClaimer {
    using SafeERC20 for IERC20;
    using Hook for uint256;

    IPendleMarketLike public pendleMarket;
    ISiloIncentivesController public incentivesController;

    /// @notice Transient variable to store the action type for which `beforeAction` was executed.
    /// @dev This is used in `afterAction` to determine if incentives need to be claimed for token transfers.
    uint256 transient internal _beforeActionExecutedFor;

    /// @dev Modifier that checks if the caller is the hook receiver.
    /// Designed to be used in the functions that are called by the hook from the silo via delegatecall.
    modifier onlyHookReceiverFromSilo() {
        require(
            msg.sender == address(ShareTokenLib.getShareTokenStorage().hookSetup.hookReceiver),
            OnlyHookReceiver()
        );
        _;
    }

    /// @inheritdoc IHookReceiver
    function initialize(ISiloConfig _config, bytes calldata _data)
        public
        initializer
        virtual
    {
        (address owner) = abi.decode(_data, (address));

        BaseHookReceiver.__BaseHookReceiver_init(_config);
        GaugeHookReceiver.__GaugeHookReceiver_init(owner);
    }

    /// @inheritdoc IPendleRewardsClaimer
    function redeemRewards()
        external
        returns (
            address[] memory rewardTokens,
            uint256[] memory rewards
        )
    {
        (address silo0, address silo1) = siloConfig.getSilos();

        if (ISilo(silo0).asset() == address(pendleMarket)) {
            return _redeemRewards(silo0);
        }

        if (ISilo(silo1).asset() == address(pendleMarket)) {
            return _redeemRewards(silo1);
        }

        revert MissingConfiguration();
    }

    /// @inheritdoc IPendleRewardsClaimer
    function setConfig(
        IPendleMarketLike _pendleMarket,
        ISiloIncentivesController _incentivesController
    ) external onlyOwner {
        (address silo0, address silo1) = siloConfig.getSilos();

        IPendleMarketLike asset0 = IPendleMarketLike(ISilo(silo0).asset());
        IPendleMarketLike asset1 = IPendleMarketLike(ISilo(silo1).asset());

        require(asset0 == _pendleMarket || asset1 == _pendleMarket, WrongPendleMarket());
        require(address(_incentivesController) != address(0), EmptyAddress());

        address notifier = ISiloIncentivesControllerGetters(address(_incentivesController)).NOTIFIER();
        require(notifier == address(this), WrongIncentivesControllerNotifier());

        address shareToken;

        if (asset0 == _pendleMarket) {
            (shareToken,,) = siloConfig.getShareTokens(silo0);
        } else {
            (shareToken,,) = siloConfig.getShareTokens(silo1);
        }

        address controllerShareToken = ISiloIncentivesControllerGetters(address(_incentivesController)).SHARE_TOKEN();
        require(shareToken == controllerShareToken, WrongIncentivesControllerShareToken());

        pendleMarket = _pendleMarket;
        incentivesController = _incentivesController;

        emit ConfigUpdated(_pendleMarket, _incentivesController);

        address silo = asset0 == _pendleMarket ? silo0 : silo1;

        _configureHooks(silo);
    }

    /// @notice Redeem rewards from Pendle
    /// @dev Redeem rewards from Pendle and transfer them to the incentives controller for immediate distribution.
    /// This function is designed to be called by the hook from the silo via delegatecall.
    /// @param _pendleMarket Pendle market address
    /// @param _incentivesController Incentives controller address
    /// @return rewardTokens Reward tokens
    /// @return rewards Rewards for collateral token
    function redeemRewardsFromPendle(
        IPendleMarketLike _pendleMarket,
        ISiloIncentivesController _incentivesController
    )
        external
        onlyHookReceiverFromSilo()
        returns (
            address[] memory rewardTokens,
            uint256[] memory rewards
        )
    {
        rewardTokens = _pendleMarket.getRewardTokens();
        rewards = _pendleMarket.redeemRewards({user: address(this)});

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            if (rewards[i] == 0) continue;

            IERC20(rewardTokens[i]).safeTransfer(address(_incentivesController), rewards[i]);
        }
    }

    /// @inheritdoc IHookReceiver
    function beforeAction(address _silo, uint256 _action, bytes calldata _inputAndOutput)
        public
        virtual
        onlySilo()
        override
    {
        uint256 collateralDepositAction = Hook.depositAction(ISilo.CollateralType.Collateral);
        require(!collateralDepositAction.matchAction(_action), CollateralDepositNotAllowed());

        beforeActionExecutedFor = _action;
        _redeemRewards(_silo);
    }

    /// @inheritdoc IHookReceiver
    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput)
        public
        virtual
        onlySiloOrShareToken()
        override(GaugeHookReceiver, IHookReceiver)
    {
        if (_beforeActionExecutedFor == Hook.NONE) {
            // This is a token transfer, and we need to redeem the rewards.
            uint256 protectedTransferAction = Hook.shareTokenTransfer(Hook.PROTECTED_TOKEN);
            if (protectedTransferAction.matchAction(_action)) _redeemRewards(_silo);
        }

        GaugeHookReceiver.afterAction(_silo, _action, _inputAndOutput);

        _beforeActionExecutedFor = Hook.NONE;
    }

    /// @notice Redeem rewards from Pendle for the silo
    /// @dev Redeem rewards from Pendle and transfer them to the incentives controller for immediate distribution.
    /// @param _silo Silo address
    /// @return rewardTokens Reward tokens
    /// @return rewards Rewards for collateral token
    function _redeemRewards(address _silo)
        internal
        returns (
            address[] memory rewardTokens,
            uint256[] memory rewards
        )
    {
        bytes memory input = abi.encodeWithSelector(
            this.redeemRewardsFromPendle.selector,
            pendleMarket,
            incentivesController
        );

        (bool success, bytes memory data) = ISilo(_silo).callOnBehalfOfSilo({
            _target: address(this),
            _value: 0,
            _callType: ISilo.CallType.Delegatecall,
            _input: input
        });

        if (!success) {
            emit FailedToClaimIncentives(_silo);
            return (rewardTokens, rewards);
        }

        (rewardTokens, rewards) = abi.decode(data, (address[], uint256[]));

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            if (rewards[i] != 0) {
                _immediateDistribution(incentivesController, rewardTokens[i], rewards[i]);
            }
        }
    }

    /// @notice Distribute the rewards to the incentives controller
    /// @dev Distribute the rewards to the incentives controller in chunks of 2^104 to avoid overflows.
    /// @param _incentivesController Incentives controller
    /// @param _rewardToken Reward token
    /// @param _totalToDistribute Amount of rewards to distribute
    function _immediateDistribution(
        ISiloIncentivesController _incentivesController,
        address _rewardToken,
        uint256 _totalToDistribute
    ) internal {
        uint256 amountToDistribute = Math.min(_totalToDistribute, type(uint104).max);

        _incentivesController.immediateDistribution(_rewardToken, uint104(amountToDistribute));

        if (amountToDistribute < _totalToDistribute) {
            uint256 remainingAmount = _totalToDistribute - amountToDistribute;
            _immediateDistribution(_incentivesController, _rewardToken, remainingAmount);
        }
    }

    /// @notice Configure the hooks for the silo
    /// @param _silo Silo address
    /// @dev Actions to be configured:
    /// - DEPOSIT
    /// - WITHDRAW
    /// - BORROW
    /// - BORROW_SAME_ASSET
    /// - REPAY
    /// - TRANSITION_COLLATERAL
    /// - SWITCH_COLLATERAL
    /// - LIQUIDATION
    /// - FLASH_LOAN
    function _configureHooks(address _silo) internal {
        uint256 requiredHooksBefore = Hook.DEPOSIT
            .addAction(Hook.WITHDRAW)
            .addAction(Hook.BORROW)
            .addAction(Hook.BORROW_SAME_ASSET)
            .addAction(Hook.REPAY)
            .addAction(Hook.TRANSITION_COLLATERAL)
            .addAction(Hook.SWITCH_COLLATERAL)
            .addAction(Hook.LIQUIDATION)
            .addAction(Hook.FLASH_LOAN)
            .addAction(Hook.COLLATERAL_TOKEN)
            .addAction(Hook.PROTECTED_TOKEN);

        uint256 protectedTransferAction = Hook.shareTokenTransfer(Hook.PROTECTED_TOKEN);
        uint256 requiredHooksAfter = _getHooksAfter(_silo).addAction(protectedTransferAction);

        _setHookConfig(_silo, uint24(requiredHooksBefore), uint24(requiredHooksAfter));
    }
}
