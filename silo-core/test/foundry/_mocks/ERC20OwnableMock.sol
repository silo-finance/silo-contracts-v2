// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC20} from "openzeppelin5/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";

contract ERC20OwnableMock is ERC20, Ownable {
    constructor(address _owner) Ownable(_owner) ERC20("ERC20OwnableMock", "E20OM") {}

    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external onlyOwner {
        _burn(account, amount);
    }
}
