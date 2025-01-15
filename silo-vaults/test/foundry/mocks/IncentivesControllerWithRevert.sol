// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract IncentivesControllerWithRevert {
    error NotificationFailed();

    function afterTokenTransfer(
        address,
        uint256,
        address,
        uint256,
        uint256,
        uint256
    ) external pure {
        revert NotificationFailed();
    }
}
