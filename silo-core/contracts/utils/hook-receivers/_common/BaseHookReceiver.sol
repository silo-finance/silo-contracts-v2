// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IHookReceiver} from "../../../interfaces/IHookReceiver.sol";
import {ISiloConfig} from "../../../interfaces/ISiloConfig.sol";

abstract contract BaseHookReceiver is IHookReceiver, Initializable {
    ISiloConfig public siloConfig;

    mapping(address silo => HookConfig) private _hookConfig;

    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc IHookReceiver
    function hookReceiverConfig(address _silo)
        external
        view
        virtual
        returns (uint24 hooksBefore, uint24 hooksAfter)
    {
        (hooksBefore, hooksAfter) = _hookReceiverConfig(_silo);
    }

    /// @notice Set the silo config
    /// @param _config Silo config
    function __BaseHookReceiver_init(ISiloConfig _config)
        internal
        onlyInitializing
        virtual
    {
        require(address(_config) != address(0), EmptySiloConfig());
        require(address(siloConfig) == address(0), AlreadyConfigured());

        siloConfig = _config;
    }

    /// @notice Set the hook config
    /// @param _silo Silo address
    /// @param _hooksBefore Hooks before
    /// @param _hooksAfter Hooks after
    function _setHookConfig(address _silo, uint256 _hooksBefore, uint256 _hooksAfter) internal virtual {
        _hookConfig[_silo] = HookConfig(uint24(_hooksBefore), uint24(_hooksAfter));
        emit HookConfigured(_silo, uint24(_hooksBefore), uint24(_hooksAfter));

        ISilo(_silo).updateHooks();
    }

    /// @notice Get the hook config
    /// @param _silo Silo address
    /// @return hooksBefore Hooks before
    /// @return hooksAfter Hooks after
    function _hookReceiverConfig(address _silo) internal view virtual returns (uint24 hooksBefore, uint24 hooksAfter) {
        HookConfig memory hookConfig = _hookConfig[_silo];

        hooksBefore = hookConfig.hooksBefore;
        hooksAfter = hookConfig.hooksAfter;
    }

    /// @notice Get the hooks before
    /// @param _silo Silo address
    /// @return hooksBefore Hooks before
    function _getHooksBefore(address _silo) internal view virtual returns (uint256 hooksBefore) {
        hooksBefore = _hookConfig[_silo].hooksBefore;
    }

    /// @notice Get the hooks after
    /// @param _silo Silo address
    /// @return hooksAfter Hooks after
    function _getHooksAfter(address _silo) internal view virtual returns (uint256 hooksAfter) {
        hooksAfter = _hookConfig[_silo].hooksAfter;
    }
}
