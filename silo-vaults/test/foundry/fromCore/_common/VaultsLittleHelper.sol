// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {CommonBase} from "forge-std/Base.sol";
import {console} from "forge-std/console.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {CAP} from "../../helpers/BaseTest.sol";
import {IntegrationTest} from "../../helpers/IntegrationTest.sol";

abstract contract VaultsLittleHelper is IntegrationTest {
    function setUp() public override {
        super.setUp();

        _setCap(allMarkets[0], CAP);
        _sortSupplyQueueIdleLast();

        // reset this, so when we porting tests we don't get unexpected results
        silo0 = ISilo(address(0));
        silo1 = ISilo(address(0));
    }

    function _deposit(uint256 _assets, address _depositor) internal override returns (uint256 shares) {
        return _makeDeposit(_assets, _depositor);
    }

    function _mint(uint256 _shares, address _depositor) internal returns (uint256 assets) {
        return _makeMint(_shares, _depositor);
    }

    function _redeem(uint256 _amount, address _depositor) internal override returns (uint256 assets) {
        vm.prank(_depositor);
        return vault.redeem(_amount, _depositor, _depositor);
    }

    function _withdraw(uint256 _amount, address _depositor) internal override returns (uint256 shares) {
        vm.prank(_depositor);
        return vault.withdraw(_amount, _depositor, _depositor);
    }

    function _makeDeposit(uint256 _assets, address _depositor) internal returns (uint256 shares) {
        vm.prank(_depositor);
        shares = vault.deposit(_assets, _depositor);
    }

    function _makeMint(uint256 _shares, address _depositor) internal returns (uint256 assets) {
        vm.prank(_depositor);
        assets = vault.mint(_shares, _depositor);
    }
}
