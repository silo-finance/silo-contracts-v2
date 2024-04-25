// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IHookReceiver {
    error RevertRequestFromHook();

    function beforeAction(address _silo, uint256 _action, bytes calldata _input) external;

    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput) external;
}
