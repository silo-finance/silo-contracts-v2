// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {VmLib, Vm} from "silo-foundry-utils/lib/VmLib.sol";

library CCIPTransferMessageLib {
    bytes32 constant internal _EVENT = keccak256("CCIPTransferMessage(bytes32)");

    error ExpectedCCIPTransferMessageEvent();

    function expectEmit() internal {
        Vm.Log[] memory entries = VmLib.vm().getRecordedLogs();

        bool hasEvent;

        for(uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == _EVENT) {
                hasEvent = true;
                break;
            }
        }

        if (!hasEvent) revert ExpectedCCIPTransferMessageEvent();
    }
}
