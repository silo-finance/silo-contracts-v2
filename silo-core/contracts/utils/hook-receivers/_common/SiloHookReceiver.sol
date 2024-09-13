// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IHookReceiver} from "../../../interfaces/IHookReceiver.sol";

abstract contract SiloHookReceiver is IHookReceiver {
    mapping(address silo => HookConfig) private _hookConfig;

    function _setHookConfig(address _silo, uint256 _hooksBefore, uint256 _hooksAfter) internal virtual {
        _hookConfig[_silo] = HookConfig(uint24(_hooksBefore), uint24(_hooksAfter));
        emit HookConfigured(_silo, uint24(_hooksBefore), uint24(_hooksAfter));

        ISilo(_silo).updateHooks();
    }

    function _hookReceiverConfig(address _silo) internal view virtual returns (uint24 hooksBefore, uint24 hooksAfter) {
        HookConfig memory hookConfig = _hookConfig[_silo];

        hooksBefore = hookConfig.hooksBefore;
        hooksAfter = hookConfig.hooksAfter;
    }

    function _getHooksBefore(address _silo) internal view virtual returns (uint256 hooksBefore) {
        hooksBefore = _hookConfig[_silo].hooksBefore;
    }

    function _getHooksAfter(address _silo) internal view virtual returns (uint256 hooksAfter) {
        hooksAfter = _hookConfig[_silo].hooksAfter;
    }
}
