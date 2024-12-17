// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {Clones} from "openzeppelin5/proxy/Clones.sol";

import {MetaMorpho} from "../../contracts/MetaMorpho.sol";
import {MetaMorphoFactory} from "../../contracts/MetaMorphoFactory.sol";
import {IMetaMorpho} from "../../contracts/interfaces/IMetaMorpho.sol";
import {EventsLib} from "../../contracts/libraries/EventsLib.sol";
import {ConstantsLib} from "../../contracts/libraries/ConstantsLib.sol";

import {IntegrationTest} from "./helpers/IntegrationTest.sol";

/*
 FOUNDRY_PROFILE=vaults-tests forge test --ffi --mc MetaMorphoFactoryTest -vvv
*/
contract MetaMorphoFactoryTest is IntegrationTest {
    MetaMorphoFactory factory;

    function setUp() public override {
        super.setUp();

        factory = new MetaMorphoFactory();
    }

    function testCreateMetaMorpho(
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
            type(MetaMorpho).creationCode,
            abi.encode(initialOwner, initialTimelock, incentivesModule, address(loanToken), name, symbol)
        );
        address expectedAddress = vm.computeCreate2Address(salt, initCodeHash, address(factory));

        vm.expectEmit(address(factory));
        emit EventsLib.CreateMetaMorpho(
            expectedAddress, address(this), initialOwner, initialTimelock, address(loanToken), name, symbol, salt
        );

        IMetaMorpho metaMorpho =
            factory.createMetaMorpho(initialOwner, initialTimelock, address(loanToken), name, symbol, salt);

        assertEq(expectedAddress, address(metaMorpho), "computeCreate2Address");

        assertTrue(factory.isMetaMorpho(address(metaMorpho)), "isMetaMorpho");

        assertEq(metaMorpho.owner(), initialOwner, "owner");
        assertEq(metaMorpho.timelock(), initialTimelock, "timelock");
        assertEq(metaMorpho.asset(), address(loanToken), "asset");
        assertEq(metaMorpho.name(), name, "name");
        assertEq(metaMorpho.symbol(), symbol, "symbol");
        assertTrue(address(metaMorpho.INCENTIVES_MODULE()) != address(0), "INCENTIVES_MODULE");
    }
}
