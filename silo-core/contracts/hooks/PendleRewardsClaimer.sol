// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

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

    IPendleMarketLike public pendleMarket;
    ISiloIncentivesController public incentivesControllerCollateral;
    ISiloIncentivesController public incentivesControllerProtected;

    /// @notice Transient variable to store the action type for which `beforeAction` was executed.
    /// @dev This is used in `afterAction` to determine if incentives need to be claimed for token transfers.
    uint256 transient beforeActionExecutedFor;

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
            uint256[] memory collateralRewards,
            uint256[] memory protectedRewards
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
        ISiloIncentivesController _incentivesControllerCollateral,
        ISiloIncentivesController _incentivesControllerProtected
    ) external onlyOwner {
        (address silo0, address silo1) = siloConfig.getSilos();

        IPendleMarketLike asset0 = IPendleMarketLike(ISilo(silo0).asset());
        IPendleMarketLike asset1 = IPendleMarketLike(ISilo(silo1).asset());

        require(asset0 == _pendleMarket || asset1 == _pendleMarket, WrongPendleMarket());
        require(address(_incentivesControllerCollateral) != address(0), EmptyAddress());
        require(address(_incentivesControllerProtected) != address(0), EmptyAddress());

        address collateralNotifier =
            ISiloIncentivesControllerGetters(address(_incentivesControllerCollateral)).NOTIFIER();

        address protectedNotifier =
            ISiloIncentivesControllerGetters(address(_incentivesControllerProtected)).NOTIFIER();

        require(collateralNotifier == address(this), WrongCollateralIncentivesControllerNotifier());
        require(protectedNotifier == address(this), WrongProtectedIncentivesControllerNotifier());

        address protectedShareToken;
        address collateralShareToken;

        if (asset0 == _pendleMarket) {
            (protectedShareToken, collateralShareToken,) = siloConfig.getShareTokens(silo0);
        } else {
            (protectedShareToken, collateralShareToken,) = siloConfig.getShareTokens(silo1);
        }

        address controllerCollateral =
            ISiloIncentivesControllerGetters(address(_incentivesControllerCollateral)).SHARE_TOKEN();

        address controllerProtected =
            ISiloIncentivesControllerGetters(address(_incentivesControllerProtected)).SHARE_TOKEN();

        require(collateralShareToken == controllerCollateral, WrongCollateralIncentivesControllerShareToken());
        require(protectedShareToken == controllerProtected, WrongProtectedIncentivesControllerShareToken());

        pendleMarket = _pendleMarket;
        incentivesControllerCollateral = _incentivesControllerCollateral;
        incentivesControllerProtected = _incentivesControllerProtected;

        emit ConfigUpdated(_pendleMarket, _incentivesControllerCollateral, _incentivesControllerProtected);

        address silo = asset0 == _pendleMarket ? silo0 : silo1;

        _configureHooks(silo);
    }

    /// @notice Redeem rewards from Pendle
    /// @dev Redeem rewards from Pendle and transfer them to the incentives controller for immediate distribution.
    /// This function is designed to be called by the hook from the silo via delegatecall.
    /// @param _pendleMarket Pendle market address
    /// @param _incentivesControllerCollateral Incentives controller address for borrowable deposits
    /// @param _incentivesControllerProtected Incentives controller address for non borrowable deposits
    /// @return rewardTokens Reward tokens
    /// @return collateralRewards Rewards for collateral token
    /// @return protectedRewards Rewards for protected token
    function redeemRewardsFromPendle(
        IPendleMarketLike _pendleMarket,
        ISiloIncentivesController _incentivesControllerCollateral,
        ISiloIncentivesController _incentivesControllerProtected
    )
        external
        onlyHookReceiverFromSilo()
        returns (
            address[] memory rewardTokens,
            uint256[] memory collateralRewards,
            uint256[] memory protectedRewards
        )
    {
        rewardTokens = _pendleMarket.getRewardTokens();
        collateralRewards = new uint256[](rewardTokens.length);
        protectedRewards = new uint256[](rewardTokens.length);
        uint256[] memory rewards = _pendleMarket.redeemRewards({user: address(this)});
        uint256 totalCollateral = IERC20(address(this)).totalSupply();
        address protectedToken = IGauge(address(_incentivesControllerProtected)).share_token();
        uint256 totalProtected = IERC20(protectedToken).totalSupply();

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            uint256 rewardAmount = rewards[i];
            IERC20 rewardToken = IERC20(rewardTokens[i]);

            if (rewardAmount == 0) continue;

            if (totalProtected == 0) {
                collateralRewards[i] = rewardAmount;
                // Transfer all rewards to the incentives controller for the collateral token
                rewardToken.safeTransfer(address(_incentivesControllerCollateral), rewardAmount);
                continue;
            }

            if (totalCollateral == 0) {
                protectedRewards[i] = rewardAmount;
                // Transfer all rewards to the incentives controller for the protected token
                rewardToken.safeTransfer(address(_incentivesControllerProtected), rewardAmount);
                continue;
            }

            // Split the rewards proportionally to the total supply of the collateral and protected tokens
            if (totalCollateral >= totalProtected) {
                collateralRewards[i] = rewardAmount * totalCollateral / (totalCollateral + totalProtected);
                protectedRewards[i] = rewardAmount - collateralRewards[i];
            } else {
                protectedRewards[i] = rewardAmount * totalProtected / (totalCollateral + totalProtected);
                collateralRewards[i] = rewardAmount - protectedRewards[i];
            }

            // Transfer the rewards to the incentives controllers
            if (collateralRewards[i] != 0) {
                rewardToken.safeTransfer(address(_incentivesControllerCollateral), collateralRewards[i]);
            }

            if (protectedRewards[i] != 0) {
                rewardToken.safeTransfer(address(_incentivesControllerProtected), protectedRewards[i]);
            }
        }
    }

    /// @inheritdoc IHookReceiver
    function beforeAction(address _silo, uint256 _action, bytes calldata _inputAndOutput)
        public
        virtual
        onlySilo()
        override
    {
        beforeActionExecutedFor = _action;
        _redeemRewards(msg.sender);
    }

    /// @inheritdoc IHookReceiver
    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput)
        public
        virtual
        onlySiloOrShareToken()
        override(GaugeHookReceiver, IHookReceiver)
    {
        if (beforeActionExecutedFor == Hook.NONE) {
            // This is a token transfer, and we need to redeem the rewards.
            _redeemRewards(msg.sender);
        }

        GaugeHookReceiver.afterAction(_silo, _action, _inputAndOutput);
    }

    /// @notice Redeem rewards from Pendle for the silo
    /// @dev Redeem rewards from Pendle and transfer them to the incentives controller for immediate distribution.
    /// @param _silo Silo address
    /// @return rewardTokens Reward tokens
    /// @return collateralRewards Rewards for collateral token
    /// @return protectedRewards Rewards for protected token
    function _redeemRewards(address _silo)
        internal
        returns (
            address[] memory rewardTokens,
            uint256[] memory collateralRewards,
            uint256[] memory protectedRewards
        )
    {
        bytes memory input = abi.encodeWithSelector(
            this.redeemRewardsFromPendle.selector,
            pendleMarket,
            incentivesControllerCollateral,
            incentivesControllerProtected
        );

        (bool success, bytes memory data) = ISilo(_silo).callOnBehalfOfSilo({
            _target: address(this),
            _value: 0,
            _callType: ISilo.CallType.Delegatecall,
            _input: input
        });

        if (!success) {
            emit FailedToClaimIncentives(_silo);
            return (rewardTokens, collateralRewards, protectedRewards);
        }

        (rewardTokens, collateralRewards, protectedRewards) = abi.decode(data, (address[], uint256[], uint256[]));

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            _immediateDistribution(incentivesControllerCollateral, rewardTokens[i], collateralRewards[i]);
            _immediateDistribution(incentivesControllerProtected, rewardTokens[i], protectedRewards[i]);
        }
    }

    /// @notice Distribute the rewards to the incentives controller
    /// @dev Distribute the rewards to the incentives controller in chunks of 2^104 to avoid overflows.
    /// @param _incentivesController Incentives controller
    /// @param _rewardToken Reward token
    /// @param _amount Amount of rewards to distribute
    function _immediateDistribution(
        ISiloIncentivesController _incentivesController,
        address _rewardToken,
        uint256 _amount
    ) internal {
        if (_amount == 0) return;

        uint256 amountToDistribute = _amount > type(uint104).max ? type(uint104).max : _amount;

        _incentivesController.immediateDistribution(_rewardToken, uint104(amountToDistribute));

        if (amountToDistribute != _amount) {
            uint256 remainingAmount = _amount - amountToDistribute;
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
        uint256 requiredHooksBefore = 
            Hook.DEPOSIT | Hook.COLLATERAL_TOKEN |
            Hook.DEPOSIT | Hook.PROTECTED_TOKEN |
            Hook.WITHDRAW | Hook.COLLATERAL_TOKEN |
            Hook.WITHDRAW | Hook.PROTECTED_TOKEN |
            Hook.BORROW |
            Hook.BORROW_SAME_ASSET |
            Hook.REPAY |
            Hook.TRANSITION_COLLATERAL | Hook.COLLATERAL_TOKEN |
            Hook.TRANSITION_COLLATERAL | Hook.PROTECTED_TOKEN |
            Hook.SWITCH_COLLATERAL |
            Hook.LIQUIDATION |
            Hook.FLASH_LOAN;

        uint256 requiredHooksAfter = _getHooksAfter(_silo) |
            Hook.COLLATERAL_TOKEN | Hook.SHARE_TOKEN_TRANSFER |
            Hook.PROTECTED_TOKEN | Hook.SHARE_TOKEN_TRANSFER;

        _setHookConfig(_silo, uint24(requiredHooksBefore), uint24(requiredHooksAfter));
    }
}
