// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {Math} from "openzeppelin5/utils/math/Math.sol";

// solhint-disable private-vars-leading-underscore
library Rounding {
    Math.Rounding internal constant UP = (Math.Rounding.Ceil);
    Math.Rounding internal constant DOWN = (Math.Rounding.Floor);
    Math.Rounding internal constant DEBT_TO_ASSETS = (Math.Rounding.Ceil);
    // COLLATERAL_TO_ASSETS is used to calculate borrower collateral (so we want to round down)
    Math.Rounding internal constant COLLATERAL_TO_ASSETS = (Math.Rounding.Floor);
    // why DEPOSIT_TO_ASSETS is Up if COLLATERAL_TO_ASSETS is Down?
    // DEPOSIT_TO_ASSETS is used for preview deposit and deposit, based on provided shares we want to pull "more" tokens
    // so we rounding up, "token flow" is in different direction than for COLLATERAL_TO_ASSETS, that's why
    // different rounding policy
    Math.Rounding internal constant DEPOSIT_TO_ASSETS = (Math.Rounding.Ceil);
    Math.Rounding internal constant DEPOSIT_TO_SHARES = (Math.Rounding.Floor);
    Math.Rounding internal constant BORROW_TO_ASSETS = (Math.Rounding.Floor);
    Math.Rounding internal constant BORROW_TO_SHARES = (Math.Rounding.Ceil);
    Math.Rounding internal constant MAX_BORROW_TO_ASSETS = (Math.Rounding.Floor);
    Math.Rounding internal constant MAX_BORROW_TO_SHARES = (Math.Rounding.Floor);
    Math.Rounding internal constant MAX_BORROW_VALUE = (Math.Rounding.Floor);
    Math.Rounding internal constant REPAY_TO_ASSETS = (Math.Rounding.Ceil);
    Math.Rounding internal constant REPAY_TO_SHARES = (Math.Rounding.Floor);
    Math.Rounding internal constant MAX_REPAY_TO_ASSETS = (Math.Rounding.Ceil);
    Math.Rounding internal constant WITHDRAW_TO_ASSETS = (Math.Rounding.Floor);
    Math.Rounding internal constant WITHDRAW_TO_SHARES = (Math.Rounding.Ceil);
    Math.Rounding internal constant MAX_WITHDRAW_TO_ASSETS = (Math.Rounding.Floor);
    Math.Rounding internal constant MAX_WITHDRAW_TO_SHARES = (Math.Rounding.Floor);
    Math.Rounding internal constant LIQUIDATE_TO_SHARES = (Math.Rounding.Floor);
    Math.Rounding internal constant LTV = (Math.Rounding.Ceil);
    Math.Rounding internal constant ACCRUED_INTEREST = (Math.Rounding.Floor);
}
