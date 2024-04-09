// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// solhint-disable private-vars-leading-underscore
library CrossReentrant {
    uint256 internal constant NOT_ENTERED = 1;
    uint256 internal constant ENTERED = 2;
    uint256 internal constant ENTERED_FROM_LEVERAGE = 3;
    uint256 internal constant ENTERED_FROM_DEPOSIT = 4;
}
