// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Math} from "openzeppelin5/utils/math/Math.sol";

// solhint-disable private-vars-leading-underscore
library Rounding {
    Math.Rounding internal constant UP = (Math.Rounding.Ceil);
    Math.Rounding internal constant DOWN = (Math.Rounding.Floor);
    Math.Rounding internal constant DEFAULT_TO_ASSETS = (Math.Rounding.Floor);
    Math.Rounding internal constant DEFAULT_TO_SHARES = (Math.Rounding.Floor);
    Math.Rounding internal constant DEBT_TO_ASSETS = (Math.Rounding.Ceil);
    // TODO why COLLATERAL_TO_ASSETS=Floor if DEPOSIT_TO_ASSETS is Ceil?
    Math.Rounding internal constant COLLATERAL_TO_ASSETS = (Math.Rounding.Floor);
    Math.Rounding internal constant DEPOSIT_TO_ASSETS = (Math.Rounding.Ceil);
    Math.Rounding internal constant DEPOSIT_TO_SHARES = (Math.Rounding.Floor);
    Math.Rounding internal constant BORROW_TO_ASSETS = (Math.Rounding.Floor);
    Math.Rounding internal constant BORROW_TO_SHARES = (Math.Rounding.Ceil);
    Math.Rounding internal constant MAX_BORROW_TO_ASSETS = (Math.Rounding.Floor);
    Math.Rounding internal constant MAX_BORROW_TO_SHARES = (Math.Rounding.Floor);
    Math.Rounding internal constant REPAY_TO_ASSETS = (Math.Rounding.Ceil);
    Math.Rounding internal constant REPAY_TO_SHARES = (Math.Rounding.Floor);
    Math.Rounding internal constant MAX_REPAY_TO_ASSETS = (Math.Rounding.Ceil);
    Math.Rounding internal constant WITHDRAW_TO_ASSETS = (Math.Rounding.Floor);
    Math.Rounding internal constant WITHDRAW_TO_SHARES = (Math.Rounding.Ceil);
    Math.Rounding internal constant MAX_WITHDRAW_TO_ASSETS = (Math.Rounding.Floor);
    Math.Rounding internal constant MAX_WITHDRAW_TO_SHARES = (Math.Rounding.Floor);
    Math.Rounding internal constant LIQUIDATE_TO_SHARES = (Math.Rounding.Floor);
    Math.Rounding internal constant LTV = (Math.Rounding.Ceil);
}
