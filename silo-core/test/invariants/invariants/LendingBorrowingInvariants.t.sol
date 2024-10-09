// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Ijnterfaces
import {ISilo} from "silo-core/contracts/Silo.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Libraries
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";

// Contracts
import {HandlerAggregator} from "../HandlerAggregator.t.sol";

/// @title LendingBorrowingInvariants
/// @notice Implements Invariants for the protocol
/// @dev Inherits HandlerAggregator to check actions in assertion testing mode
abstract contract LendingBorrowingInvariants is HandlerAggregator {
    using SiloLensLib for ISilo;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          LENDING                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    function assert_LENDING_INVARIANT_A(address silo, address user) internal {
        uint256 maxWithdrawal = ISilo(silo).maxWithdraw(user);
        uint256 liquidity = ISilo(silo).getLiquidity();

        assertLe(maxWithdrawal, liquidity, LENDING_INVARIANT_A);
    }

    function assert_LENDING_INVARIANT_C(address silo, address user) internal {
        if (siloConfig.getDebtSilo(user) == address(0)) {
            uint256 balance = IERC20(silo).balanceOf(user);
            if (ISilo(silo).getLiquidity() > balance) {
                assertEq(
                    ISilo(silo).maxRedeem(user),
                    balance,
                    LENDING_INVARIANT_C
                );
            }
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                        BORROWING                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_BORROWING_INVARIANT_A(
        address silo,
        address debtToken,
        address user
    ) internal {
        uint256 debtAssets = ISilo(silo).getDebtAssets();
        uint256 userDebt = IERC20(debtToken).balanceOf(user);

        assertGe(debtAssets, debtAssets, BORROWING_INVARIANT_A);
    }

    function assert_BORROWING_INVARIANT_B(address silo, uint256 sumUserDebt)
        internal
    {
        uint256 debtAssets = ISilo(silo).getDebtAssets();

        assertEq(debtAssets, sumUserDebt, BORROWING_INVARIANT_B);
    }

    function assert_BORROWING_INVARIANT_D(address silo, address user) internal {
        bool hasDebt = siloConfig.hasDebtInOtherSilo(silo, user);
        if (hasDebt) {
            assertGt(IERC20(silo).balanceOf(user), 0, BORROWING_INVARIANT_D);
        }
    }

    function assert_BORROWING_INVARIANT_E(address user) internal {
        uint256 debtSilo0 = IERC20(debtTokens[0]).balanceOf(user);
        uint256 debtSilo1 = IERC20(debtTokens[1]).balanceOf(user);

        if (debtSilo0 != 0) {
            assertEq(debtSilo1, 0, BORROWING_INVARIANT_E);
        } else if (debtSilo1 != 0) {
            assertEq(debtSilo0, 0, BORROWING_INVARIANT_E);
        }
    }

    function assert_BORROWING_INVARIANT_F(address silo, address debtAsset)
        internal
    {
        uint256 totalAssets = ISilo(silo).totalAssets();

        if (totalAssets != 0) {
            assertGt(IERC20(debtAsset).totalSupply(), 0, BORROWING_INVARIANT_F);
        }
    }

    function assert_BORROWING_INVARIANT_G(address silo, address user) internal {
        uint256 debtSilo0 = IERC20(debtTokens[0]).balanceOf(user);
        uint256 debtSilo1 = IERC20(debtTokens[1]).balanceOf(user);

        if (debtSilo0 == 0 && debtSilo1 == 0) {
            assertTrue(ISilo(silo).isSolvent(user), BORROWING_INVARIANT_G);
            assertEq(ISilo(silo).getLtv(user), 0, BORROWING_INVARIANT_G);
        }
    }

    function assert_BORROWING_INVARIANT_H(
        address silo,
        address collateralShareToken,
        address user
    ) internal {
        uint256 maxRedeem = ISilo(silo).maxRedeem(user);
        uint256 balance = IERC20(collateralShareToken).balanceOf(user);

        assertLe(maxRedeem, balance, BORROWING_INVARIANT_H);
    }
}
