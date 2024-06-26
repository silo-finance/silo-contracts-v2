// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IMethodsRegistry} from "../interfaces/IMethodsRegistry.sol";
import {SiloMethodsRegistry} from "./SiloMethodsRegistry.sol";
import {SiloConfigMethodsRegistry} from "./SiloConfigMethodsRegistry.sol";

contract Registries {
    IMethodsRegistry[] public registry;

    constructor() {
        registry.push(IMethodsRegistry(address(new SiloMethodsRegistry())));
        registry.push(IMethodsRegistry(address(new SiloConfigMethodsRegistry())));
    }

    function list() external view returns (IMethodsRegistry[] memory) {
        return registry;
    }
}
