// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ERC20} from "openzeppelin5/token/ERC20/ERC20.sol";

contract ERC20Mint is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address _account, uint256 _amount) external {
        _mint(_account, _amount);
    }
}
