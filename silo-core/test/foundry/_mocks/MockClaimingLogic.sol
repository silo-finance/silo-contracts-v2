// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IIncentivesClaimingLogic} from "silo-vaults/contracts/interfaces/IIncentivesClaimingLogic.sol";

// Mock Contract Definition for testing IIncentivesClaimingLogic interactions
contract MockClaimingLogic is IIncentivesClaimingLogic {
    struct TimesCalledStorage {
        uint256 timesCalled;
    }
    
    address internal immutable _SELF;

    event ClaimRewardsCalled(address siloContext, address claimingLogic, address caller, uint256 currentTimesCalled);

    constructor() {
        _SELF = address(this);
    }

    function claimRewardsAndDistribute() external override {
        TimesCalledStorage storage $ = _timesCalledStorage();
        $.timesCalled++;
        emit ClaimRewardsCalled(address(this), _SELF, msg.sender, $.timesCalled);
    }

    function _timesCalledStorage() private view returns (TimesCalledStorage storage $) {
        bytes32 slot = keccak256(abi.encodePacked(_SELF, "timesCalled"));
        assembly {
            $.slot := slot
        }
    }
}
