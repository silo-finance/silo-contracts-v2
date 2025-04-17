// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {ERC4626Test} from "a16z-erc4626-tests/ERC4626.test.sol";

import {IntegrationTest} from "./helpers/IntegrationTest.sol";

/*
 FOUNDRY_PROFILE=vaults_tests forge test --ffi --mc ERC4626ComplianceTest -vvv
*/
contract ERC4626ComplianceTest is IntegrationTest, ERC4626Test {
    function setUp() public override(IntegrationTest, ERC4626Test) {
        super.setUp();
        loanToken.setOnDemand(false);
        collateralToken.setOnDemand(false);

        _underlying_ = address(loanToken);
        _vault_ = address(vault);
        _delta_ = 0;
        _vaultMayBeEmpty = true;
        _unlimitedAmount = true;

        _setCap(allMarkets[0], 100e18);
        _sortSupplyQueueIdleLast();
    }
}
