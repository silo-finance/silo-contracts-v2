// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {IERC3156FlashLender} from "silo-core/contracts/interfaces/IERC3156FlashLender.sol";
import {IGeneralSwapModule} from "silo-core/contracts/interfaces/IGeneralSwapModule.sol";
import {IPartialLiquidationByDefaulting} from "silo-core/contracts/interfaces/IPartialLiquidationByDefaulting.sol";
import {PausableWithAccessControl} from "common/utils/PausableWithAccessControl.sol";
import {RescueModule} from "silo-core/contracts/leverage/modules/RescueModule.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {Actor} from "silo-core/test/invariants/utils/Actor.sol";

// Libraries
import {console2} from "forge-std/console2.sol";

// Test Contracts
import {BaseHandlerDefaulting} from "../../base/BaseHandlerDefaulting.t.sol";
import {TestERC20} from "silo-core/test/invariants/utils/mocks/TestERC20.sol";
import {TestWETH} from "silo-core/test/echidna-leverage/utils/mocks/TestWETH.sol";
import {MockSiloOracle} from "silo-core/test/invariants/utils/mocks/MockSiloOracle.sol";

/*
- if LP provider does not claim, rewards balance can only grow
- total supply of collateral and protected must stay the same before and after liquidation 
- in case price 1:1 defaulting should not create any loss (if done before bad debt)
- all rewards are claimable always
- if LTV > LT_MARGIN, defaulting never reverts (notice: cap)
- 1 wei debt liquidation: possible! keeper will not get any rewards
- after defaultin we should not reduce collateral total assets below actual available balance (liquidity)
*/

/// @title DefaultingHandler
/// @notice Handler test contract for a set of actions
contract DefaultingHandler is BaseHandlerDefaulting {
    // TODO finalize this implementation
    function liquidationCallByDefaulting(uint256 _maxDebtToCover, RandomGenerator memory _random)
        external
        setupRandomActor(_random.i)
    {
        bool success;
        bytes memory returnData;

        // only actors can borrow
        address borrower = _getRandomActor(_random.j);

        _setTargetActor(_getRandomActor(_random.i));

        _before();

        (success, returnData) = actor.proxy(
            address(liquidationModule),
            abi.encodeWithSignature("liquidationCallByDefaulting(address,uint256)", borrower, _maxDebtToCover)
        );

        if (success) {
            revert("liquidation by defaulting done!");
        }

        _after();

        _assert_defaulting_totalAssetsDoesNotChange();
    }

    function _assert_defaulting_totalAssetsDoesNotChange() internal {
        assertEq(
            defaultVarsBefore[address(vault0)].totalAssets,
            defaultVarsAfter[address(vault0)].totalAssets,
            "[silo0] total collateral assets should not change after defaulting"
        );

        assertEq(
            defaultVarsBefore[address(vault1)].protectedShares,
            defaultVarsAfter[address(vault1)].protectedShares,
            "[silo1] total protected assets should not change after defaulting"
        );
    }

    // TODO rules
}
