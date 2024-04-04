// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

library ConstantsLib {
    uint256 internal constant METHOD_EXTERNAL = 0;
    uint256 internal constant METHOD_BORROW_SAME_TOKEN = 1;
    uint256 internal constant METHOD_BORROW_TWO_TOKENS = 2;
    uint256 internal constant METHOD_BORROW_POSSIBLE = 2;
    uint256 internal constant METHOD_WITHDRAW = 3;
    uint256 internal constant METHOD_IS_SOLVENT = 4;
    uint256 internal constant METHOD_DEPOSIT = 5;
}
