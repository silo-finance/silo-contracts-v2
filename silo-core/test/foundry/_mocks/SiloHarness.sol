// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Silo, ISiloFactory} from "silo-core/contracts/Silo.sol";

contract SiloHarness is Silo {
    constructor(ISiloFactory _factory) Silo(_factory) {}

    function hookReceiver() external view returns (address) {
        return address(sharedStorage.hookReceiver);
    }
}
