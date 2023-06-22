// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor(string memory _name) ERC20(_name, _name) {}

    function mint(address _holder, uint256 _amount) external {
        _mint(_holder, _amount);
    }
}
