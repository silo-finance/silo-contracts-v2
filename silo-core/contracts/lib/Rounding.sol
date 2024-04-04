// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {MathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";

library Rounding {
    uint256 internal constant DEFAULT_TO_ASSETS = uint256(MathUpgradeable.Rounding.Down);
    uint256 internal constant DEFAULT_TO_SHARES = uint256(MathUpgradeable.Rounding.Down);
    uint256 internal constant DEBT_TO_ASSETS = uint256(MathUpgradeable.Rounding.Up);
    uint256 internal constant COLLATERAL_TO_ASSETS = uint256(MathUpgradeable.Rounding.Down);
    uint256 internal constant BORROW_TO_ASSETS = uint256(MathUpgradeable.Rounding.Down);
    uint256 internal constant BORROW_TO_SHARES = uint256(MathUpgradeable.Rounding.Up);
    uint256 internal constant MAX_BORROW_TO_ASSETS = uint256(MathUpgradeable.Rounding.Down);
    uint256 internal constant MAX_BORROW_TO_SHARES = uint256(MathUpgradeable.Rounding.Down);
    uint256 internal constant REPAY_TO_ASSETS = uint256(MathUpgradeable.Rounding.Up);
    uint256 internal constant REPAY_TO_SHARES = uint256(MathUpgradeable.Rounding.Down);
    uint256 internal constant MAX_REPAY_TO_ASSETS = uint256(MathUpgradeable.Rounding.Up);
    uint256 internal constant DEPOSIT_TO_ASSETS = uint256(MathUpgradeable.Rounding.Up);
    uint256 internal constant DEPOSIT_TO_SHARES = uint256(MathUpgradeable.Rounding.Down);
    uint256 internal constant WITHDRAW_TO_ASSETS = uint256(MathUpgradeable.Rounding.Down);
    uint256 internal constant WITHDRAW_TO_SHARES = uint256(MathUpgradeable.Rounding.Up);
    uint256 internal constant MAX_WITHDRAW_TO_ASSETS = uint256(MathUpgradeable.Rounding.Down);
    uint256 internal constant MAX_WITHDRAW_TO_SHARES = uint256(MathUpgradeable.Rounding.Down);
    uint256 internal constant LIQUIDATE_TO_SHARES = uint256(MathUpgradeable.Rounding.Down);
    uint256 internal constant LTV = uint256(MathUpgradeable.Rounding.Up);
    uint256 internal constant UP = uint256(MathUpgradeable.Rounding.Up);
    uint256 internal constant DOWN = uint256(MathUpgradeable.Rounding.Down);
}
