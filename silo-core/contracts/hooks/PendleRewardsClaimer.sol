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
import {IPendleRewardsClaimer} from "silo-core/contracts/interfaces/IPendleRewardsClaimer.sol";
import {GaugeHookReceiver} from "silo-core/contracts/hooks/gauge/GaugeHookReceiver.sol";
import {PartialLiquidation} from "silo-core/contracts/hooks/liquidation/PartialLiquidation.sol";
import {BaseHookReceiver} from "silo-core/contracts/hooks/_common/BaseHookReceiver.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {ShareTokenLib} from "silo-core/contracts/lib/ShareTokenLib.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

/// @title PendleRewardsClaimer
/// @notice This hook allows to redeem rewards from Pendle for the silo.
contract PendleRewardsClaimer is GaugeHookReceiver, PartialLiquidation, IPendleRewardsClaimer {
    using SafeERC20 for IERC20;
    using Hook for uint256;

    IPendleMarketLike internal _pendleMarket;
    ISilo internal _pendleMarketSilo;
    IShareToken internal _protectedShareToken;

    /// @notice Transient variable to store the action type for which `beforeAction` was executed.
    /// @dev This is used in `afterAction` to determine if incentives need to be claimed for token transfers.
    bool transient internal _rewardsClaimedInTheBeforeAction;

    /// @inheritdoc IHookReceiver
    function initialize(ISiloConfig _config, bytes calldata _data)
        public
        initializer
        virtual
    {
        (address owner) = abi.decode(_data, (address));

        BaseHookReceiver.__BaseHookReceiver_init(_config);
        GaugeHookReceiver.__GaugeHookReceiver_init(owner);
        PendleRewardsClaimer.__PendleRewardsClaimer_init();
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
        virtual
        returns (
            address[] memory rewardTokens,
            uint256[] memory rewards
        )
    {
        IPendleMarketLike pendleMarket = _pendleMarket;
        rewardTokens = pendleMarket.getRewardTokens();
        pendleMarket.redeemRewards({user: address(this)});
        rewards = new uint256[](rewardTokens.length);

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address rewardToken = rewardTokens[i];
            // Pendle should never distribute rewards in the Pendle market LP tokens.
            // However, we have this check in place as a safety measure,
            // so we will ensure that we do not transfer assets from the Silo balance.
            if (rewardToken == address(pendleMarket)) continue;

            uint256 rewardAmount = IERC20(rewardToken).balanceOf(address(this));
            if (rewardAmount == 0) continue;

            IERC20(rewardToken).safeTransfer(address(_incentivesController), rewardAmount);
            rewards[i] = rewardAmount;
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

        _rewardsClaimedInTheBeforeAction = true;
        redeemRewards();
    }

    /// @inheritdoc IHookReceiver
    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput)
        public
        virtual
        onlySiloOrShareToken()
        override(GaugeHookReceiver, IHookReceiver)
    {
        // As we have configured all before actions to be executed,
        // we expect that rewards be redeemed in the before action. But, share tokens do not have before action hook.
        // Therefore, we need to verify if this is a protected share token transfer,
        // and if so, we must redeem the rewards.
        if (!_rewardsClaimedInTheBeforeAction) {
            uint256 protectedTransferAction = Hook.shareTokenTransfer(Hook.PROTECTED_TOKEN);
            if (protectedTransferAction.matchAction(_action)) redeemRewards();
        }

        GaugeHookReceiver.afterAction(_silo, _action, _inputAndOutput);

        _rewardsClaimedInTheBeforeAction = false;
    }

    /// @notice Redeem rewards from Pendle for the Silo
    /// @dev Redeem rewards from Pendle and transfer them to the incentives controller for immediate distribution.
    /// @return rewardTokens Reward tokens
    /// @return rewards Rewards for collateral token
    function redeemRewards() public virtual returns (address[] memory rewardTokens, uint256[] memory rewards) {
        ISilo silo = _pendleMarketSilo;
        IPendleMarketLike pendleMarket = _pendleMarket;
        ISiloIncentivesController controller = _getIncentivesControllerSafe();
        bytes memory input = abi.encodeWithSelector(this.redeemRewardsFromPendle.selector, pendleMarket, controller);

        (bool success, bytes memory data) = silo.callOnBehalfOfSilo({
            _target: address(this),
            _value: 0,
            _callType: ISilo.CallType.Delegatecall,
            _input: input
        });

        if (!success) {
            emit FailedToClaimIncentives(silo);
            return (rewardTokens, rewards);
        }

        (rewardTokens, rewards) = abi.decode(data, (address[], uint256[]));

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            uint256 rewardAmount = rewards[i];
            if (rewardAmount == 0) continue;

            // Rewards amount for distribution is capped to 2^104 to avoid overflows.
            // Also, to avoid code over complication we do not distribute rewards amounts above 2^104.
            // In the case if we will receive for any reason abnormal amount of rewards
            // all rewards will be sent to the incentives controller and can be rescued if needed
            // and redistributed by the incentives controller owner.
            uint256 amountToDistribute = Math.min(rewardAmount, type(uint104).max);
            controller.immediateDistribution(rewardTokens[i], uint104(amountToDistribute));
        }
    }

    /// @notice Initialize the `PendleRewardsClaimer`
    /// @dev Initialize the `PendleRewardsClaimer` by detecting the Pendle market and Silo.
    /// Also, configure the hooks for the Silo.
    function __PendleRewardsClaimer_init() internal virtual {
        (ISilo silo, IPendleMarketLike pendleMarket) = _getPendleMarketSilo();

        _configureHooks(address(silo));

        (address protectedShareToken,,) = siloConfig.getShareTokens(address(silo));

        _pendleMarketSilo = silo;
        _pendleMarket = pendleMarket;
        _protectedShareToken = IShareToken(protectedShareToken);
    }

    /// @notice Get the Pendle market and Silo
    /// @dev Detects the Pendle market and Silo by calling `redeemRewards` on the asset.
    /// @return silo
    /// @return pendleMarket
    function _getPendleMarketSilo() private returns (ISilo silo, IPendleMarketLike pendleMarket) {
        (address silo0, address silo1) = siloConfig.getSilos();

        IPendleMarketLike asset0 = IPendleMarketLike(ISilo(silo0).asset());
        IPendleMarketLike asset1 = IPendleMarketLike(ISilo(silo1).asset());

        if (!_redeemRewardsReverts(asset0)) {
            // If it does not revert for the silo0, we require it to revert for the silo1
            require(_redeemRewardsReverts(asset1), WrongSiloConfig());
            return (ISilo(silo0), asset0);
        } else {
            // If it reverts for silo0, we require it not to revert for the silo1.
            require(!_redeemRewardsReverts(asset1), WrongSiloConfig());
            return (ISilo(silo1), asset1);
        }
    }

    /// @notice Check if the `redeemRewards` function reverts
    /// @param _market Pendle market
    /// @return result True if the `redeemRewards` function reverts, false otherwise
    function _redeemRewardsReverts(IPendleMarketLike _market) private returns (bool redeemReverts) {
        try _market.redeemRewards(address(this)) returns (uint256[] memory) {
            result = false;
        } catch {
            result = true;
        }
    }

    /// @notice Configure the hooks for the silo
    /// @param _silo Silo address
    function _configureHooks(address _silo) private {
        // we require all before actions to be configured
        uint24 hooksBefore = type(uint24).max;

        uint256 hooksAfter = _getHooksAfter(_silo);
        uint256 protectedTransferAction = Hook.shareTokenTransfer(Hook.PROTECTED_TOKEN);
        hooksAfter = hooksAfter.addAction(protectedTransferAction);

        _setHookConfig(_silo, hooksBefore, uint24(hooksAfter));
    }

    /// @notice Get the incentives controller from the `GaugeHookReceiver` configuration.
    /// @dev Reverts if the incentives controller is not configured.
    /// @return controller
    function _getIncentivesControllerSafe() private returns (ISiloIncentivesController controller) {
        controller = ISiloIncentivesController(address(configuredGauges[_protectedShareToken]));
        require(address(controller) != address(0), IncentivesControllerRequired());
    }
}
