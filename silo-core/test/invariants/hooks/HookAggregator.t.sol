// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Hook Contracts
import {DefaultBeforeAfterHooks} from "./DefaultBeforeAfterHooks.t.sol";
import {console2} from "forge-std/console2.sol";

/// @title HookAggregator
/// @notice Helper contract to aggregate all before / after hook contracts, inherited on each handler
abstract contract HookAggregator is DefaultBeforeAfterHooks {
    /// @notice Modular hook selector, per module
    function _before() internal {
        for (uint256 i; i < silos.length; i++) {
            _defaultHooksBefore(silos[i]);
        }
    }

    function _printDefaultVars(mapping(address => DefaultVars) storage _defaultVars) internal view {
        for (uint256 i; i < silos.length; i++) {
            DefaultVars memory vars = _defaultVars[silos[i]];

            console2.log("Silo %s  DefaultVars:", silos[i]);
            console2.log("  Total Supply: %s", vars.totalSupply);
            console2.log("  Exchange Rate: %s", vars.exchangeRate);
            console2.log("  Total Assets: %s", vars.totalAssets);
            console2.log("  Supply Cap: %s", vars.supplyCap);
            console2.log("  Debt Assets: %s", vars.debtAssets);
            console2.log("  Collateral Assets: %s", vars.collateralAssets);
            console2.log("  Balance: %s", vars.balance);
            console2.log("  Cash: %s", vars.cash);
            console2.log("  Interest Rate: %s", vars.interestRate);
            console2.log("  Borrow Cap: %s", vars.borrowCap);
            console2.log("  DAO and Deployer Fees: %s", vars.daoAndDeployerFees);
            console2.log("  Protected Shares: %s", vars.protectedShares);
            console2.log("  Collateral Shares: %s", vars.collateralShares);
            console2.log("  User Debt Shares: %s", vars.userDebtShares);
            console2.log("  User Debt: %s", vars.userDebt);
            console2.log("  User Assets: %s", vars.userAssets);
            console2.log("  User Balance: %s", vars.userBalance);
            console2.log("  Interest Rate Timestamp: %s", vars.interestRateTimestamp);
            console2.log("  Borrower Collateral Silo: %s", vars.borrowerCollateralSilo);
            console2.log("  Is Solvent: %s", vars.isSolvent);
            console2.log("-----------------------------");
        }
    }

    function _printDefaultVarsBefore() internal view {
        console2.log("DefaultVars Before:");
        _printDefaultVars(defaultVarsBefore);
    }

    function _printDefaultVarsAfter() internal view {
        console2.log("DefaultVars After:");
        _printDefaultVars(defaultVarsAfter);
    }

    /// @notice Modular hook selector,\n per module
    function _after() internal {
        for (uint256 i; i < silos.length; i++) {
            _defaultHooksAfter(silos[i]);

            // Postconditions
            _checkPostConditions(silos[i]);
        }
    }

    /// @notice Postconditions for the handlers
    function _checkPostConditions(address silo) internal {
        // BASE
        assert_BASE_GPOST_A(silo);
        assert_BASE_GPOST_BC(silo);
        assert_BASE_GPOST_D(silo);

        // BORROWING
        assert_BORROWING_GPOST_C(silo);
    }
}
