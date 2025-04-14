// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {ERC4626Test} from "a16z-erc4626-tests/ERC4626.test.sol";

import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/*
 FOUNDRY_PROFILE=core_test forge test --ffi --mc ERC4626ComplianceTest -vvv
*/
contract ERC4626ComplianceTest is SiloLittleHelper, ERC4626Test {
    function setUp() public override {
        _setUpLocalFixture();

        token0.setOnDemand(false);
        token1.setOnDemand(false);

        _underlying_ = address(token1);
        _vault_ = address(silo1);
        _delta_ = 0;
        _vaultMayBeEmpty = true;
        _unlimitedAmount = true;
    }
}
