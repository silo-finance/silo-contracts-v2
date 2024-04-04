// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// solhint-disable private-vars-leading-underscore
library Methods {
    uint256 internal constant EXTERNAL = 0; // for any external project
    uint256 internal constant BORROW_SAME_TOKEN = 1;
    uint256 internal constant BORROW_TWO_TOKENS = 2;
    uint256 internal constant BORROW_POSSIBLE = 3;
    uint256 internal constant WITHDRAW = 4;
    uint256 internal constant IS_SOLVENT = 5;
    uint256 internal constant DEPOSIT = 6;
}
