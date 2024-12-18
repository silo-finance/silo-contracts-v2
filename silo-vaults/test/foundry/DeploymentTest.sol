// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {ConstantsLib} from "../../contracts/libraries/ConstantsLib.sol";
import {IMetaSilo} from "../../contracts/interfaces/IMetaSilo.sol";
import {MetaSilo} from "../../contracts/MetaSilo.sol";

import {IntegrationTest} from "./helpers/IntegrationTest.sol";

/*
 FOUNDRY_PROFILE=vaults-tests forge test --ffi --mc DeploymentTest -vvv
*/
contract DeploymentTest is IntegrationTest {
    /*
     FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testDeployMetaSiloNotToken -vvv
    */
    function testDeployMetaSiloNotToken() public {
        address notToken = makeAddr("address notToken");

        vm.expectRevert();
        createMetaSilo(OWNER, ConstantsLib.MIN_TIMELOCK, notToken, "MetaSilo Vault", "MMV");
    }

    /*
     FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testDeployMetaSiloPass -vvv
    */
    function testDeployMetaSiloPass(
        address owner,
        uint256 initialTimelock,
        string memory name,
        string memory symbol
    ) public {
        assumeNotZeroAddress(owner);
        initialTimelock = bound(initialTimelock, ConstantsLib.MIN_TIMELOCK, ConstantsLib.MAX_TIMELOCK);

        IMetaSilo newVault = createMetaSilo(owner, initialTimelock, address(loanToken), name, symbol);

        assertEq(newVault.owner(), owner, "owner");
        assertEq(newVault.timelock(), initialTimelock, "timelock");
        assertEq(newVault.asset(), address(loanToken), "asset");
        assertEq(newVault.name(), name, "name");
        assertEq(newVault.symbol(), symbol, "symbol");
    }
}
