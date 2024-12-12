// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Incentives Distribution Solution interface
interface IIncentivesDistributionSolution {
    /// @notice Called after a token transfer.
    /// @dev Notifies the solution about the token transfer.
    function afterTokenTransfer(
        address _sender,
        uint256 _senderBalance,
        address _recipient,
        uint256 _recipientBalance,
        uint256 _totalSupply,
        uint256 _amount
    ) external;
}
