// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Ijnterfaces
import {ISilo} from "silo-core/contracts/Silo.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Contracts
import {HandlerAggregator} from "../HandlerAggregator.t.sol";

/// @title BaseInvariants
/// @notice Implements Invariants for the protocol
/// @dev Inherits HandlerAggregator to check actions in assertion testing mode
abstract contract BaseInvariants is HandlerAggregator {
    function assert_BASE_INVARIANT_A(address silo) internal {
        uint256 totalAssets = ISilo(silo).totalAssets();
        uint256 totalSupply = ISilo(silo).totalSupply();
        assertEq(totalAssets == 0, totalSupply == 0, BASE_INVARIANT_A);
    }

    function assert_BASE_INVARIANT_B(address silo, address debtShareToken)
        internal
    {
        uint256 totalAtotalSupplyssets = IERC20(debtShareToken).totalSupply();
        uint256 totalDebtAssets = ISilo(silo).getDebtAssets();
        assertEq(
            totalAtotalSupplyssets == 0,
            totalDebtAssets == 0,
            BASE_INVARIANT_B
        );
    }

    function assert_BASE_INVARIANT_C(address silo) internal {
        (
            uint192 daoAndDeployerFees,
            uint64 interestRateTimestamp,
            ,
            ,

        ) = ISilo(silo).getSiloStorage();
        if (interestRateTimestamp == 0) {
            assertEq(daoAndDeployerFees, 0, BASE_INVARIANT_C);
        }
    }

    function assert_BASE_INVARIANT_D(
        address silo,
        address debtToken,
        address protectedToken,
        address user
    ) internal {
        if (
            ISilo(silo).isSolvent(user) && IERC20(debtToken).balanceOf(user) > 0
        ) {
            assertEq(IERC20(silo).balanceOf(user), 0, BASE_INVARIANT_D);
            assertEq(
                IERC20(protectedToken).balanceOf(user),
                0,
                BASE_INVARIANT_D
            );
        }
    }

    function assert_BASE_INVARIANT_E(address silo, address asset) internal {
        uint256 totalAssets = ISilo(silo).totalAssets();
        uint256 balance = IERC20(asset).balanceOf(silo);
        assertGe(balance, totalAssets, BASE_INVARIANT_D);
    }

    function assert_BASE_INVARIANT_F(address silo, address asset) internal {
        uint256 liquidity = ISilo(silo).getLiquidity();
        uint256 balance = IERC20(asset).balanceOf(silo);
        uint256 protectedAssets = ISilo(silo).getTotalAssetsStorage(
            uint256(ISilo.AssetType.Protected)
        );
        uint256 daoAndDeployerRevenue = _getDaoAndDeployerFees(silo);
        assertLe(
            liquidity,
            balance - protectedAssets - daoAndDeployerRevenue,
            BASE_INVARIANT_F
        );
    }

    function assert_BASE_INVARIANT_G(address silo, address asset) internal {
        (, , uint256 protectedAssets, , ) = ISilo(silo).getSiloStorage();
        uint256 balance = IERC20(asset).balanceOf(silo);
        assertLe(protectedAssets, balance, BASE_INVARIANT_F);
    }

    function assert_BASE_INVARIANT_H() internal {
        assertFalse(siloConfig.reentrancyGuardEntered(), BASE_INVARIANT_H);
    }
}
