// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// solhint-disable private-vars-leading-underscore
library CrossEntrancy {
    uint24 internal constant NOT_ENTERED = 1;
    uint24 internal constant ENTERED = 2; // default for any method that not have dedicated flag
    uint24 internal constant ENTERED_FROM_LEVERAGE = 3;
    uint24 internal constant ENTERED_FROM_DEPOSIT = 4;
}