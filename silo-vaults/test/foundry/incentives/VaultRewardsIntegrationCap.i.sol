// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {VaultRewardsIntegrationTest} from "./VaultRewardsIntegration.i.sol";

/*
 FOUNDRY_PROFILE=vaults_tests forge test --ffi --mc VaultRewardsIntegrationCap -vvv
*/
contract VaultRewardsIntegrationCap is VaultRewardsIntegrationTest {
    function _cap() internal view virtual override returns (uint256) {
        return 1e3;
    }
}
