// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";

contract TokenRescuer {
    using SafeERC20 for IERC20;

    error EmptyRecipient();
    event TokensRescued(address indexed executor, address indexed token, uint256 amount);

    function _rescueTokens(address _recipient, IERC20 _token) internal virtual {
        if (_recipient == address(0)) revert EmptyRecipient();

        uint256 amount = _token.balanceOf(address(this));
        _token.safeTransfer(_recipient, amount);

        emit TokensRescued(msg.sender, address(_token), amount);
    }
}
