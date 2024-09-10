// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {ISiloConfig} from "./ISiloConfig.sol";

interface IHookReceiver {
    struct HookConfig {
        uint24 hooksBefore;
        uint24 hooksAfter;
    }

    event HookConfigured(address silo, uint24 hooksBefore, uint24 hooksAfter);

    error RevertRequestFromHook();

    /// @notice Initialize a hook receiver
    /// @param _siloConfig Silo configuration with all the details about the silo
    /// @param _data Data to initialize the hook receiver (if needed)
    function initialize(ISiloConfig _siloConfig, bytes calldata _data) external;

    /// @notice state of Silo before action, can be also without interest, if you need them, call silo.accrueInterest()
    function beforeAction(
        address _silo,
        uint256 _action,
        bytes calldata _input
    )
        external
        returns (bool interruptExecution);

    function afterAction(
        address _silo,
        uint256 _action,
        bytes calldata _inputAndOutput
    )
        external
        returns (bool interruptExecution);

    /// @notice return hooksBefore and hooksAfter configuration
    function hookReceiverConfig(address _silo) external view returns (uint24 hooksBefore, uint24 hooksAfter);
}
