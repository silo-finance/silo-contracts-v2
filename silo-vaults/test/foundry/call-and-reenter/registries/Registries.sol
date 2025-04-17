// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IMethodsRegistry} from "silo-core/test/foundry/Silo/reentrancy/interfaces/IMethodsRegistry.sol";
import {SiloVaultMethodsRegistry} from "./SiloVaultMethodsRegistry.sol";

contract Registries {
    IMethodsRegistry[] public registry;

    constructor() {
        registry.push(IMethodsRegistry(address(new SiloVaultMethodsRegistry())));
    }

    function list() external view returns (IMethodsRegistry[] memory) {
        return registry;
    }
}
