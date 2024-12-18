// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {Clones} from "openzeppelin5/proxy/Clones.sol";

import {MetaSilo} from "../../contracts/MetaSilo.sol";
import {MetaSiloFactory} from "../../contracts/MetaSiloFactory.sol";
import {IMetaSilo} from "../../contracts/interfaces/IMetaSilo.sol";
import {EventsLib} from "../../contracts/libraries/EventsLib.sol";
import {ConstantsLib} from "../../contracts/libraries/ConstantsLib.sol";

import {IntegrationTest} from "./helpers/IntegrationTest.sol";

/*
 FOUNDRY_PROFILE=vaults-tests forge test --ffi --mc MetaSiloFactoryTest -vvv
*/
contract MetaSiloFactoryTest is IntegrationTest {
    MetaSiloFactory factory;

    function setUp() public override {
        super.setUp();

        factory = new MetaSiloFactory();
    }

    function testCreateMetaSilo(
        address initialOwner,
        uint256 initialTimelock,
        string memory name,
        string memory symbol,
        bytes32 salt
    ) public {
        vm.assume(address(initialOwner) != address(0));
        initialTimelock = bound(initialTimelock, ConstantsLib.MIN_TIMELOCK, ConstantsLib.MAX_TIMELOCK);

        address incentivesModule = Clones.predictDeterministicAddress(factory.VAULT_INCENTIVES_MODULE_IMPLEMENTATION(), salt, address(factory));

        bytes32 initCodeHash = hashInitCode(
            type(MetaSilo).creationCode,
            abi.encode(initialOwner, initialTimelock, incentivesModule, address(loanToken), name, symbol)
        );
        address expectedAddress = vm.computeCreate2Address(salt, initCodeHash, address(factory));

        vm.expectEmit(address(factory));
        emit EventsLib.CreateMetaSilo(
            expectedAddress, address(this), initialOwner, initialTimelock, address(loanToken), name, symbol, salt
        );

        IMetaSilo MetaSilo =
            factory.createMetaSilo(initialOwner, initialTimelock, address(loanToken), name, symbol, salt);

        assertEq(expectedAddress, address(MetaSilo), "computeCreate2Address");

        assertTrue(factory.isMetaSilo(address(MetaSilo)), "isMetaSilo");

        assertEq(MetaSilo.owner(), initialOwner, "owner");
        assertEq(MetaSilo.timelock(), initialTimelock, "timelock");
        assertEq(MetaSilo.asset(), address(loanToken), "asset");
        assertEq(MetaSilo.name(), name, "name");
        assertEq(MetaSilo.symbol(), symbol, "symbol");
        assertTrue(address(MetaSilo.INCENTIVES_MODULE()) != address(0), "INCENTIVES_MODULE");
    }
}
