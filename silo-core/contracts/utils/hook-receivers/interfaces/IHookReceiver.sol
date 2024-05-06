// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

interface IHookReceiver {
    struct HookConfig {
        uint24 hooksBefore;
        uint24 hooksAfter;
    }

    event HookConfigured(address silo, uint24 hooksBefore, uint24 hooksAfter);

    error RevertRequestFromHook();

    /// @notice Initialize a hook receiver
    /// @param _timelock Timelock controller (DAO)
    /// @param _siloConfig Silo configuration with all the details about the silo
    function initialize(address _timelock, ISiloConfig _siloConfig) external;

    /// @notice state of Silo before action, can be also without interest, if you need them, call silo.accrueInterest()
    function beforeAction(address _silo, uint256 _action, bytes calldata _input) external;

    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput) external;

    /// @notice return hooksBefore and hooksAfter configuration
    function hookReceiverConfig(address _silo) external view returns (uint24 hooksBefore, uint24 hooksAfter);
}
