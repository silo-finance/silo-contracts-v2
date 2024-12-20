// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {SiloVault} from "../../contracts/SiloVault.sol";
import {SiloVaultsFactory} from "../../contracts/SiloVaultsFactory.sol";
import {VaultIncentivesModule} from "../../contracts/incentives/VaultIncentivesModule.sol";
import {ISiloVault} from "../../contracts/interfaces/ISiloVault.sol";
import {EventsLib} from "../../contracts/libraries/EventsLib.sol";
import {ConstantsLib} from "../../contracts/libraries/ConstantsLib.sol";

import {IntegrationTest} from "./helpers/IntegrationTest.sol";

/*
 FOUNDRY_PROFILE=vaults-tests forge test --ffi --mc SiloVaultsFactoryTest -vvv
*/
contract SiloVaultsFactoryTest is IntegrationTest {
    SiloVaultsFactory factory;

    function setUp() public override {
        super.setUp();

        factory = new SiloVaultsFactory();
    }

    function testCreateSiloVault(
        address initialOwner,
        uint256 initialTimelock,
        string memory name,
        string memory symbol
    ) public {
        vm.assume(address(initialOwner) != address(0));
        initialTimelock = bound(initialTimelock, ConstantsLib.MIN_TIMELOCK, ConstantsLib.MAX_TIMELOCK);

        ISiloVault siloVault =
            factory.createSiloVault(initialOwner, initialTimelock, address(loanToken), name, symbol);

        assertTrue(factory.isSiloVault(address(siloVault)), "isSiloVault");

        assertEq(siloVault.owner(), initialOwner, "owner");
        assertEq(siloVault.timelock(), initialTimelock, "timelock");
        assertEq(siloVault.asset(), address(loanToken), "asset");
        assertEq(siloVault.name(), name, "name");
        assertEq(siloVault.symbol(), symbol, "symbol");
        assertTrue(address(siloVault.INCENTIVES_MODULE()) != address(0), "INCENTIVES_MODULE");
    }
}
