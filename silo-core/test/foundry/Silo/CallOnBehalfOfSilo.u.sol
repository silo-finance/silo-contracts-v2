// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {StdStorage, stdStorage} from "forge-std/StdStorage.sol";

import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {SiloHarness} from "silo-core/test/foundry/_mocks/SiloHarness.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {ERC20OwnableMock} from "silo-core/test/foundry/_mocks/ERC20OwnableMock.sol";

// FOUNDRY_PROFILE=core-test forge test --mc CallOnBehalfOfSiloTest --ffi -vvv
contract CallOnBehalfOfSiloTest is Test {
    using stdStorage for StdStorage;

    SiloHarness public silo;
    ERC20OwnableMock public token;

    address siloFactory = makeAddr("SiloFactory");
    address hookReceiver = makeAddr("HookReceiver");
    address thridParty = makeAddr("ThirdParty");

    function setUp() public {
        silo = new SiloHarness(ISiloFactory(siloFactory));
        token = new ERC20OwnableMock(address(silo));
    }

    function testOnlySiloCanExcute() public {
        uint256 tokensToMint = 100;

        // only silo can mint tokens (mock contract permissions test)
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        token.mint(address(this), tokensToMint);

        vm.prank(address(silo));
        token.mint(address(this), tokensToMint);
        assertEq(token.balanceOf(address(this)), tokensToMint);
    }

    function testCallOnBehalfOfSilo() public {
        uint256 tokensToMint = 100;
        address target = address(token);
        bytes memory data = abi.encodeWithSelector(ERC20OwnableMock.mint.selector, thridParty, tokensToMint);

        vm.expectRevert(ISilo.OnlyHookReceiver.selector);
        silo.callOnBehalfOfSilo(target, data);

        assertEq(token.balanceOf(thridParty), 0);

        stdstore
            .target(address(silo))
            .sig(SiloHarness.hookReceiver.selector)
            .checked_write(hookReceiver);

        vm.prank(hookReceiver);
        silo.callOnBehalfOfSilo(target, data);

        assertEq(token.balanceOf(thridParty), tokensToMint);
    }
}
