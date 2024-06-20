// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// solhint-disable private-vars-leading-underscore
library CrossEntrancy {
    uint24 internal constant NOT_ENTERED = 1;
    uint24 internal constant ENTERED = 2; // default for any method that not have dedicated flag
    uint24 internal constant ENTERED_FROM_LEVERAGE = 3;
    uint24 internal constant ENTERED_FROM_DEPOSIT = 4;
    uint24 internal constant ENTERED_FOR_LIQUIDATION = 5;
    uint24 internal constant ENTERED_FOR_LIQUIDATION_REPAY = 6;
    uint24 internal constant ENTERED_FOR_LIQUIDATION_WITHDRAW = 7;
}
