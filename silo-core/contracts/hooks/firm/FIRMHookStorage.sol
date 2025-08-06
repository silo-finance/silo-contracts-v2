// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

library FIRMHookStorage {
    struct FIRMHookStorageData {
        uint256 maturityDate;
        address firm;
        address firmVault;
    }

    // keccak256(abi.encode(uint256(keccak256("silo.hooks.firm.FIRMHook.storage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant _STORAGE_LOCATION = 0xd7513ffe3a01a9f6606089d1b67011bca35bec018ac0faa914e1c529408f8300;

    function get() internal pure returns (FIRMHookStorageData storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := _STORAGE_LOCATION
        }
    }
}
