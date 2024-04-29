// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IHookReceiver {
    struct HookConfig {
        uint24 hooksBefore;
        uint24 hooksAfter;
    }

    error RevertRequestFromHook();

    /// @notice state of Silo before action, can be also without interest, if you need them, call silo.accrueInterest()
    function beforeAction(address _silo, uint256 _action, bytes calldata _input) external;

    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput) external;

    /// @notice return hooksBefore and hooksAfter configuration
    function hookReceiverConfig() external view returns (uint24 hooksBefore, uint24 hooksAfter);
}
