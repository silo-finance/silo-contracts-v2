// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {console2} from "forge-std/console2.sol";

import {Strings} from "openzeppelin5/utils/Strings.sol";

import {IERC3156FlashLender} from "silo-core/contracts/interfaces/IERC3156FlashLender.sol";
import {IGeneralSwapModule} from "silo-core/contracts/interfaces/IGeneralSwapModule.sol";
import {IPartialLiquidationByDefaulting} from "silo-core/contracts/interfaces/IPartialLiquidationByDefaulting.sol";
import {PausableWithAccessControl} from "common/utils/PausableWithAccessControl.sol";
import {RescueModule} from "silo-core/contracts/leverage/modules/RescueModule.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {Actor} from "silo-core/test/invariants/utils/Actor.sol";

// Libraries

// Test Contracts
import {BaseHandlerDefaulting} from "../../base/BaseHandlerDefaulting.t.sol";
import {TestERC20} from "silo-core/test/invariants/utils/mocks/TestERC20.sol";
import {TestWETH} from "silo-core/test/echidna-leverage/utils/mocks/TestWETH.sol";
import {MockSiloOracle} from "silo-core/test/invariants/utils/mocks/MockSiloOracle.sol";

/*
- all rewards are claimable always
- if LTV > LT_MARGIN, defaulting never reverts (notice: cap)
- 1 wei debt liquidation: possible! keeper will not get any rewards
- after defaultin we should not reduce collateral total assets below actual available balance (liquidity)

Risks:
- liquidation breaks VAULT standard 
- there is no user input, so there is no risk from "outside" 
- "weird" liquidation eg 1 wei do weird stuff
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

        _after();

        if (success) {
            (, uint256 repayDebtAssets) = abi.decode(returnData, (uint256, uint256));
            assertGt(repayDebtAssets, 0, "repayDebtAssets should be greater than 0 on any liquidation");

            assertLt(
                defaultVarsAfter[address(vault1)].debtAssets,
                defaultVarsBefore[address(vault1)].debtAssets,
                "debt assets should decrease after liquidation"
            );
        }

        _assert_defaulting_totalAssetsDoesNotChange();
    }

    function assert_claimRewardsCanBeAlwaysDone(uint256 _actorIndex) external setupRandomActor(_actorIndex) {
        bool success;
        bytes memory returnData;

        // we will NEVER claim rewards form actor[0], that one will be used for checking rule about rewards balance
        if (address(actor) == _getRandomActor(0)) return;

        (success, returnData) = actor.proxy(address(gauge), abi.encodeWithSignature("claimRewards(address)", actor));

        if (!success) revert("claimRewards failed");
    }

    /*
    total supply of collateral and protected must stay the same before and after liquidation
    */
    function _assert_defaulting_totalAssetsDoesNotChange() internal {
        assertEq(
            defaultVarsBefore[address(vault0)].totalAssets,
            defaultVarsAfter[address(vault0)].totalAssets,
            "[silo0] total collateral assets should not change after defaulting (on collateral silo)"
        );

        assertEq(
            defaultVarsBefore[address(vault0)].totalProtectedAssets,
            defaultVarsAfter[address(vault0)].totalProtectedAssets,
            "[silo0] total protected assets should not change after defaulting (on collateral silo)"
        );

        assertEq(
            defaultVarsBefore[address(vault1)].totalProtectedAssets,
            defaultVarsAfter[address(vault1)].totalProtectedAssets,
            "[silo1] total protected assets should not change after defaulting (on debt silo)"
        );
    }

    /*
    in case price 1:1 defaulting should not create any loss (if done before bad debt)
    */
    function _assets_noLossWhenNoBadDebt() internal {}

    /*
    - if LP provider does not claim, rewards balance can only grow
    */
    function assert_rewardsBalanceCanOnlyGrowWhenNoClaim() external setupRandomActor(0) {
        assertGe(
            gauge.getRewardsBalance(address(actor), _getProgramNames()),
            rewardsBalanceBefore[address(actor)],
            "rewards balance should not decrease when no claim"
        );
    }

    // TODO rules
}
