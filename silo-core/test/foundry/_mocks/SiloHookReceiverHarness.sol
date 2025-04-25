// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {BaseHookReceiver} from "silo-core/contracts/hooks/_common/BaseHookReceiver.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

contract SiloHookReceiverHarness is BaseHookReceiver {
    function setHookConfig(address _silo, uint24 _hooksBefore, uint24 _hooksAfter) external virtual {
        _setHookConfig(_silo, _hooksBefore, _hooksAfter);
    }

    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput) external virtual {}

    function beforeAction(address _silo, uint256 _action, bytes calldata _input) external virtual {}

    function initialize(ISiloConfig _siloConfig, bytes calldata _data) public virtual override {}

    function hookReceiverConfig(address _silo) external view override returns (uint24 hooksBefore, uint24 hooksAfter) {
        (hooksBefore, hooksAfter) = _hookReceiverConfig(_silo);
    }

    function getHooksBefore(address _silo) external view virtual returns (uint256 hooksBefore) {
        hooksBefore = _getHooksBefore(_silo);
    }

    function getHooksAfter(address _silo) external view virtual returns (uint256 hooksAfter) {
        hooksAfter = _getHooksAfter(_silo);
    }
}
