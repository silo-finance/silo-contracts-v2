// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IHookReceiver} from "../interfaces/IHookReceiver.sol";

abstract contract SiloHookReceiver is IHookReceiver {
    HookConfig internal _hookConfig;

    function hookReceiverConfig() external view returns (uint24 hooksBefore, uint24 hooksAfter) {
        HookConfig memory hookConfig = _hookConfig;

        hooksBefore = hookConfig.hooksBefore;
        hooksAfter = hookConfig.hooksAfter;
    }
}
