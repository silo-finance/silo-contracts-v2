// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IGaugeLike {
    function afterTokenTransfer(
        address _sender,
        uint256 _senderBalance,
        address _recipient,
        uint256 _recipientBalance,
        uint256 _totalSupply
    ) external;

    function shareToken() external view returns (address);
    // solhint-disable-next-line func-name-mixedcase
    function is_killed() external view returns (bool);
}
