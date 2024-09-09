// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ERC20} from "openzeppelin5/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";

contract SILOTokenLike is ERC20, Ownable {
    constructor() ERC20("Test SILO", "SILO-LIKE") Ownable(msg.sender) {}
    function mint(address _account, uint256 _amount) external onlyOwner {
        _mint(_account, _amount);
    }
}
