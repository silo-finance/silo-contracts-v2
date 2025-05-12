// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {ERC4626Test} from "a16z-erc4626-tests/ERC4626.test.sol";

import {ERC20Mock} from "openzeppelin5/mocks/token/ERC20Mock.sol";

import {XSilo, XRedeemPolicy, ERC20} from "../../contracts/XSilo.sol";

/*
 FOUNDRY_PROFILE=x_silo forge test --ffi --mc ERC4626ComplianceTest -vvv
*/
contract ERC4626ComplianceTest is ERC4626Test {
    function setUp() public override {
        ERC20Mock asset = new ERC20Mock();
        XSilo vault = new XSilo(address(this), address(asset));

        _underlying_ = address(asset);
        _vault_ = address(vault);
        _delta_ = 0;
        _vaultMayBeEmpty = true;
        _unlimitedAmount = true;
    }
}
