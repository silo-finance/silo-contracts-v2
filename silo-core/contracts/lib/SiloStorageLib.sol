// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";

library SiloStorageLib {
    // keccak256(abi.encode(uint256(keccak256("silo.vault.storage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant SiloStorageLocation = 0xd23602b72f41ed90b205c2e081f54c36008bd2fd64116fed2217b5f0954f8c00;

    function getSiloStorage() internal pure returns (ISilo.SiloStorage storage $) {
        assembly {
            $.slot := SiloStorageLocation
        }
    }
}
