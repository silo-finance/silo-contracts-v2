// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title ShareDebtTokenLike
/// @notice Harness token for Certora verification that simulates debt share token with receive approvals
/// @dev This is a simplified ERC20 token with additional receive approval functionality
contract ShareDebtTokenLike is ERC20 {
    // Mapping from owner to spender to receive allowance amount
    // receiveAllowances[owner][spender] = amount that spender can mint for owner
    mapping(address => mapping(address => uint256)) private _receiveAllowances;

    event ReceiveApproval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    /// @notice Increase the receive allowance that allows `msg.sender` to mint tokens for `_owner`
    /// @param _owner The address that will receive the minted tokens
    /// @param _addedValue The amount to increase the allowance by
    function increaseReceiveAllowance(address _owner, uint256 _addedValue) external {
        require(_owner != address(0), "Owner is zero address");
        
        uint256 currentAllowance = _receiveAllowances[_owner][msg.sender];
        uint256 newAllowance = currentAllowance + _addedValue;
        
        _receiveAllowances[_owner][msg.sender] = newAllowance;
        emit ReceiveApproval(_owner, msg.sender, newAllowance);
    }

    /// @notice Mint tokens for a specific receiver using the receive approval
    /// @param _tokensReceiver The address to receive the minted tokens
    /// @param _amount The amount of tokens to mint
    function mintFor(address _tokensReceiver, uint256 _amount) external {
        require(_tokensReceiver != address(0), "Receiver is zero address");
        
        uint256 currentAllowance = _receiveAllowances[_tokensReceiver][msg.sender];
        require(currentAllowance >= _amount, "Insufficient receive allowance");
        
        // Decrease the allowance
        unchecked {
            _receiveAllowances[_tokensReceiver][msg.sender] = currentAllowance - _amount;
        }
        
        // Mint tokens to the receiver
        _mint(_tokensReceiver, _amount);
    }

    /// @notice Get the receive allowance for a spender to mint tokens for an owner
    /// @param _owner The address that would receive the tokens
    /// @param _spender The address that can mint tokens
    /// @return The current receive allowance
    function receiveAllowance(address _owner, address _spender) external view returns (uint256) {
        return _receiveAllowances[_owner][_spender];
    }

    /// @notice Set receive allowance (for harness testing purposes)
    /// @param _owner The address that would receive the tokens
    /// @param _spender The address that can mint tokens
    /// @param _amount The allowance amount to set
    function setReceiveAllowance(address _owner, address _spender, uint256 _amount) external {
        _receiveAllowances[_owner][_spender] = _amount;
        emit ReceiveApproval(_owner, _spender, _amount);
    }
}