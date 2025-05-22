// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IIncentivesClaimingLogic} from "silo-vaults/contracts/interfaces/IIncentivesClaimingLogic.sol";

// Mock Contract Definition for testing IIncentivesClaimingLogic interactions
contract MockClaimingLogicReverts is IIncentivesClaimingLogic {
    address internal immutable _SELF;

    error ClaimRewardsReverts(address siloContext, address claimingLogic, address caller);

    constructor() {
        _SELF = address(this);
    }

    function claimRewardsAndDistribute() external override {
        revert ClaimRewardsReverts(address(this), _SELF, msg.sender);
    }
}