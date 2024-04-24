// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IHookReceiver {
    error RevertRequestFromHook();

    /// @return hookReturnCode calls to hooks are done using low level call and internal reverts are ignored.
    /// In order to have some communication from hook -> silo, we can use return codes
    function beforeAction(address _silo, uint256 _action, bytes calldata _input)
        external
        returns (uint256 hookReturnCode);

    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput)
        external
        returns (uint256 hookReturnCode);
}
