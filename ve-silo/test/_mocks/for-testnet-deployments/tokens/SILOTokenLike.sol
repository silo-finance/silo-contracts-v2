// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ERC20} from "openzeppelin5/token/ERC20/ERC20.sol";

contract SILOTokenLike is ERC20, Ownable {
    constructor() ERC20("Test SILO", "SILO-LIKE") {}
    function mint(address _account, uint256 _amount) external onlyOwner {
        _mint(_account, _amount);
    }
}
