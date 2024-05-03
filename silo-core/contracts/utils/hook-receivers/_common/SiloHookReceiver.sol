// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IHookReceiver} from "../interfaces/IHookReceiver.sol";

abstract contract SiloHookReceiver is IHookReceiver {
    mapping(address silo => HookConfig) private _hookConfig;

    function hookReceiverConfig(address _silo) external view returns (uint24 hooksBefore, uint24 hooksAfter) {
        HookConfig memory hookConfig = _hookConfig[_silo];

        hooksBefore = hookConfig.hooksBefore;
        hooksAfter = hookConfig.hooksAfter;
    }

    function _setHookConfig(address _silo, uint24 _hooksBefore, uint24 _hooksAfter) internal {
        _hookConfig[_silo] = HookConfig(_hooksBefore, _hooksAfter);
        emit HookConfigured(_silo, _hooksBefore, _hooksAfter);

        ISilo(_silo).updateHooks();
    }

    function _getHooksBefore(address _silo) internal view returns (uint24 hooksBefore) {
        hooksBefore = _hookConfig[_silo].hooksBefore;
    }

    function _getHooksAfter(address _silo) internal view returns (uint24 hooksAfter) {
        hooksAfter = _hookConfig[_silo].hooksAfter;
    }
}
