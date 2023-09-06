// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IGauge {
    function afterTokenTransfer(
        address _sender,
        uint256 _senderBalance,
        address _recipient,
        uint256 _recipientBalance,
        uint256 _totalSupply
    ) external;
}
