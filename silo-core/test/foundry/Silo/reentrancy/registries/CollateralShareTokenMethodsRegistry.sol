// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ShareTokenMethodsRegistry} from "./ShareTokenMethodsRegistry.sol";

contract CollateralShareTokenMethodsRegistry is ShareTokenMethodsRegistry {
    constructor() ShareTokenMethodsRegistry() {
    }

    function abiFile() external pure override returns (string memory) {
        return "/cache/foundry/out/silo-core/ShareCollateralToken.sol/ShareCollateralToken.json";
    }
}