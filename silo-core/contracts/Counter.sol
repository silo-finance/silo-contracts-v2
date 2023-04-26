// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.6;

import "@openzeppelin/contracts-3.4.1/access/Ownable.sol";

contract Counter is Ownable {
    uint256 public number;

    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    function increment() public {
        number++;
    }
}
