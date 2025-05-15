// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {
    SiloVault, PendingUint192, PendingAddress, IERC4626, MarketConfig, ConstantsLib, Math, IVaultIncentivesModule
} from "silo-vaults/contracts/SiloVault.sol";

import {IIncentivesClaimingLogic} from "silo-vaults/contracts/interfaces/IIncentivesClaimingLogic.sol";


contract SiloVaultHarness is SiloVault {

    constructor(
        address owner,
        uint256 initialTimelock,
        IVaultIncentivesModule _vaultIncentivesModule,
        address _asset,
        string memory _name,
        string memory _symbol,
        address _incentivesClaimingLogic
    ) SiloVault(owner, initialTimelock, _vaultIncentivesModule, _asset, _name, _symbol) {
        incentivesClaimingLogic = _incentivesClaimingLogic;
    }

    address immutable incentivesClaimingLogic;

    // function _claimRewards() internal override {
    //     bytes memory data = abi.encodeWithSelector(IIncentivesClaimingLogic.claimRewardsAndDistribute.selector);
    //     incentivesClaimingLogic.delegatecall(data);
    // }

    function pendingTimelock_() external view returns (PendingUint192 memory) {
        return pendingTimelock;
    }

    function pendingGuardian_() external view returns (PendingAddress memory) {
        return pendingGuardian;
    }

    function config_(IERC4626 id) external view returns (MarketConfig memory) {
        return config[id];
    }

    function pendingCap_(IERC4626 id) external view returns (PendingUint192 memory) {
        return pendingCap[id];
    }

    function balanceTracker_(IERC4626 id) external view returns (uint256) {
        return balanceTracker[id];
    }

    function minTimelock() external pure returns (uint256) {
        return ConstantsLib.MIN_TIMELOCK;
    }

    function maxTimelock() external pure returns (uint256) {
        return ConstantsLib.MAX_TIMELOCK;
    }

    function maxQueueLength() external pure returns (uint256) {
        return ConstantsLib.MAX_QUEUE_LENGTH;
    }

    function maxFee() external pure returns (uint256) {
        return ConstantsLib.MAX_FEE;
    }

    function nextGuardianUpdateTime() external view returns (uint256 nextTime) {
        nextTime = block.timestamp + timelock;

        if (pendingTimelock.validAt != 0) {
            nextTime = Math.min(nextTime, pendingTimelock.validAt + pendingTimelock.value);
        }

        uint256 validAt = pendingGuardian.validAt;
        if (validAt != 0) nextTime = Math.min(nextTime, validAt);
    }

    function nextCapIncreaseTime(IERC4626 id) external view returns (uint256 nextTime) {
        nextTime = block.timestamp + timelock;

        if (pendingTimelock.validAt != 0) {
            nextTime = Math.min(nextTime, pendingTimelock.validAt + pendingTimelock.value);
        }

        uint256 validAt = pendingCap[id].validAt;
        if (validAt != 0) nextTime = Math.min(nextTime, validAt);
    }

    function nextTimelockDecreaseTime() external view returns (uint256 nextTime) {
        nextTime = block.timestamp + timelock;

        if (pendingTimelock.validAt != 0) nextTime = Math.min(nextTime, pendingTimelock.validAt);
    }

    function nextRemovableTime(IERC4626 id) external view returns (uint256 nextTime) {
        nextTime = block.timestamp + timelock;

        if (pendingTimelock.validAt != 0) {
            nextTime = Math.min(nextTime, pendingTimelock.validAt + pendingTimelock.value);
        }

        uint256 removableAt = config[id].removableAt;
        if (removableAt != 0) nextTime = Math.min(nextTime, removableAt);
    }

    function getVaultAsset(IERC4626 id) external view returns (address asset) {
        return id.asset();
    }

    function lock() external view returns (bool) {
        return _lock;
    }

    // Incentives contracts are trusted. It is a security assumption. delegatecalls to malicious targets will break
    // the rules.
    function _afterTokenTransfer(address, address, uint256) internal virtual override {}
    function _claimRewards() internal virtual override {}

    function supplyQGetAt(uint256 index) external view returns (IERC4626)
    {
        return supplyQueue[index];
    }

    function supplyQLength() external view returns (uint256)
    {
        return supplyQueue.length;
    }
    function withdrawQGetAt(uint256 index) external view returns (IERC4626)
    {
        return withdrawQueue[index];
    }

    function withdrawQLength() external view returns (uint256)
    {
        return withdrawQueue.length;
    }
}
