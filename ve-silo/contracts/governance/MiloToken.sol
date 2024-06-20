// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {ERC20Permit, ERC20} from "openzeppelin5/token/ERC20/extensions/ERC20Permit.sol";
import {Context} from "openzeppelin5/utils/Context.sol";

contract MiloToken is ERC20Permit, Ownable {
    constructor() ERC20("Milo", "MILO") ERC20Permit("Milo") Ownable(_msgSender()) {}

    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }

    function burn(uint256 _amount) external onlyOwner {
        _burn(_msgSender(), _amount);
    }
}
