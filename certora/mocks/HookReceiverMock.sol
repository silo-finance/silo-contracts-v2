// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

contract HookReceiverMock {
    function afterTokenTransfer(
        address,
        uint256,
        address,
        uint256,
        uint256,
        uint256
    ) external {}
}
