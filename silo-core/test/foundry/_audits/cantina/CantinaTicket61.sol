// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ShareDebtToken} from "silo-core/contracts/utils/ShareDebtToken.sol";

import {CantinaTicket} from "./CantinaTicket.sol";

/*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mc CantinaTicket61
*/
contract CantinaTicket61 is CantinaTicket {
    function testDebtApproval() public {
        token0.setOnDemand(true);

        address alice = makeAddr("alice");
        address bob = makeAddr("bob");

        _deposit(1e18, alice);
        _depositForBorrow(1e18, alice);
        _borrow(10, alice);

        ISiloConfig.ConfigData memory config = siloConfig.getConfig(address(silo1));

        vm.prank(alice);
        ShareDebtToken(config.debtShareToken).setReceiveApproval(bob, 1e18);

        uint256 aliceDebtBefore = IShareToken(config.debtShareToken).balanceOf(alice);
        /*
            bob can now borrow new assets for themselves while giving the debt share
            tokens to alice.
        */
        vm.prank(bob);
        silo1.borrowSameAsset(123, bob, alice);

        assertEq(IShareToken(config.debtShareToken).balanceOf(alice), aliceDebtBefore + 123, "alice got more debt");
    }
}
