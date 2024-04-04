// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {MathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";

// solhint-disable private-vars-leading-underscore
library Rounding {
    MathUpgradeable.Rounding internal constant UP = (MathUpgradeable.Rounding.Up);
    MathUpgradeable.Rounding internal constant DOWN = (MathUpgradeable.Rounding.Down);
    MathUpgradeable.Rounding internal constant DEFAULT_TO_ASSETS = (MathUpgradeable.Rounding.Down);
    MathUpgradeable.Rounding internal constant DEFAULT_TO_SHARES = (MathUpgradeable.Rounding.Down);
    MathUpgradeable.Rounding internal constant DEBT_TO_ASSETS = (MathUpgradeable.Rounding.Up);
    MathUpgradeable.Rounding internal constant COLLATERAL_TO_ASSETS = (MathUpgradeable.Rounding.Down);
    MathUpgradeable.Rounding internal constant DEPOSIT_TO_ASSETS = (MathUpgradeable.Rounding.Up);
    MathUpgradeable.Rounding internal constant DEPOSIT_TO_SHARES = (MathUpgradeable.Rounding.Down);
    MathUpgradeable.Rounding internal constant BORROW_TO_ASSETS = (MathUpgradeable.Rounding.Down);
    MathUpgradeable.Rounding internal constant BORROW_TO_SHARES = (MathUpgradeable.Rounding.Up);
    MathUpgradeable.Rounding internal constant MAX_BORROW_TO_ASSETS = (MathUpgradeable.Rounding.Down);
    MathUpgradeable.Rounding internal constant MAX_BORROW_TO_SHARES = (MathUpgradeable.Rounding.Down);
    MathUpgradeable.Rounding internal constant REPAY_TO_ASSETS = (MathUpgradeable.Rounding.Up);
    MathUpgradeable.Rounding internal constant REPAY_TO_SHARES = (MathUpgradeable.Rounding.Down);
    MathUpgradeable.Rounding internal constant MAX_REPAY_TO_ASSETS = (MathUpgradeable.Rounding.Up);
    MathUpgradeable.Rounding internal constant WITHDRAW_TO_ASSETS = (MathUpgradeable.Rounding.Down);
    MathUpgradeable.Rounding internal constant WITHDRAW_TO_SHARES = (MathUpgradeable.Rounding.Up);
    MathUpgradeable.Rounding internal constant MAX_WITHDRAW_TO_ASSETS = (MathUpgradeable.Rounding.Down);
    MathUpgradeable.Rounding internal constant MAX_WITHDRAW_TO_SHARES = (MathUpgradeable.Rounding.Down);
    MathUpgradeable.Rounding internal constant LIQUIDATE_TO_SHARES = (MathUpgradeable.Rounding.Down);
    MathUpgradeable.Rounding internal constant LTV = (MathUpgradeable.Rounding.Up);
}
