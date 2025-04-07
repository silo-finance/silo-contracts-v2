// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

contract IncentivesClaimingLogicWithRevert {
    error RevertInClaimingLogic();

    function claimRewards(address) external pure {
        revert RevertInClaimingLogic();
    }
}
