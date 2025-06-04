// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {PendleRewardsClaimer} from "silo-core/contracts/hooks/PendleRewardsClaimer.sol";

contract PendleRewardsClaimerHarness is PendleRewardsClaimer {
    function resetTransientRewardsClaimed() public {
        _rewardsClaimed = false;
    }
}
