// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IGaugeLike {
    function afterTokenTransfer(
        address _sender,
        uint256 _senderBalance,
        address _recipient,
        uint256 _recipientBalance,
        uint256 _totalSupply,
        uint256 _amount
    ) external;

    // solhint-disable func-name-mixedcase
    function share_token() external view returns (address);
    function is_killed() external view returns (bool);
    // solhint-enable func-name-mixedcase
}
