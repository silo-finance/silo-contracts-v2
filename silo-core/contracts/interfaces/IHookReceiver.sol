// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IHookReceiver {
    function afterTokenTransfer(
        address _sender,
        uint256 _senderBalance,
        address _recipient,
        uint256 _recipientBalance,
        uint256 _totalSupply,
        uint256 _amount
    ) external;
}
