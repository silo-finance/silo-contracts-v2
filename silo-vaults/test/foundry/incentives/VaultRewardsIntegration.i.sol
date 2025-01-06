// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";

import {SiloIncentivesControllerGaugeLike} from "silo-core/contracts/incentives/SiloIncentivesControllerGaugeLike.sol";
import {DistributionTypes} from "silo-core/contracts/incentives/lib/DistributionTypes.sol";
import {SiloIncentivesController} from "silo-core/contracts/incentives/SiloIncentivesController.sol";
import {SiloMathLib} from "silo-core/contracts/lib/SiloMathLib.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IGaugeHookReceiver} from "silo-core/contracts/interfaces/IGaugeHookReceiver.sol";
import {IGaugeLike} from "silo-core/contracts/interfaces/IGaugeLike.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";
import {MintableToken} from "silo-core/test/foundry/_common/MintableToken.sol";

import {SiloIncentivesControllerCL} from "../../../contracts/incentives/claiming-logics/SiloIncentivesControllerCL.sol";

import {INotificationReceiver} from "../../../contracts/interfaces/INotificationReceiver.sol";
import {IntegrationTest} from "../helpers/IntegrationTest.sol";

import {CAP} from "../helpers/BaseTest.sol";

/*
 FOUNDRY_PROFILE=vaults-tests forge test --ffi --mc VaultRewardsIntegrationTest -vvv
*/
contract VaultRewardsIntegrationTest is IntegrationTest {
    MintableToken reward1 = new MintableToken(18);

    SiloIncentivesControllerGaugeLike siloIncentivesController;
    SiloIncentivesController vaultIncentivesController;

    function setUp() public virtual override {
        super.setUp();

        _setCap(allMarkets[0], _cap());
        _setCap(allMarkets[1], _cap());
        _setCap(allMarkets[2], _cap());

        reward1.setOnDemand(true);

        vaultIncentivesController = new SiloIncentivesController(address(this), address(vault));
        vm.label(address(vaultIncentivesController), "VaultIncentivesController");

        // SiloIncentivesController is per silo
        siloIncentivesController = new SiloIncentivesControllerGaugeLike(
            address(this), address(partialLiquidation), address(silo1)
        );

        // set SiloIncentivesController as gauge for hook
        vm.prank(Ownable(address(partialLiquidation)).owner());
        IGaugeHookReceiver(address(partialLiquidation)).setGauge(
            IGaugeLike(address(siloIncentivesController)), IShareToken(address(silo1))
        );

        _sortSupplyQueueIdleLast();
        assertEq(address(vault.supplyQueue(0)), address(silo1), "supplyQueue[0] == silo1");

        (, uint24 hooksAfter) = IGaugeHookReceiver(address(partialLiquidation)).hookReceiverConfig(address(silo1));
        assertEq(hooksAfter, Hook.COLLATERAL_TOKEN | Hook.SHARE_TOKEN_TRANSFER, "hook after");
    }

    function _cap() internal view virtual returns (uint256) {
        return CAP;
    }

    /*
     FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt test_vaults_rewards_noRevert -vv
    */
    function test_vaults_rewards_noRevert() public {
        uint256 amount = 1e18;
        uint256 shares = amount * SiloMathLib._DECIMALS_OFFSET_POW;
        uint256 sharesCapped = amount > _cap() ? _cap() * SiloMathLib._DECIMALS_OFFSET_POW : shares;

        vm.expectCall(
            address(partialLiquidation),
            abi.encodeWithSelector(
                IHookReceiver.afterAction.selector,
                address(silo1),
                Hook.COLLATERAL_TOKEN | Hook.SHARE_TOKEN_TRANSFER,
                abi.encodePacked(
                    address(0),
                    address(vault),
                    uint256(sharesCapped),
                    uint256(0),
                    uint256(sharesCapped),
                    uint256(sharesCapped)
                )
            )
        );

        vault.deposit(amount, address(this));
        assertEq(silo1.totalSupply(), sharesCapped, "we expect deposit to go to silo");

        // does not revert without incentives setup:

        vault.claimRewards();
        siloIncentivesController.claimRewards(address(this));

        assertEq(reward1.balanceOf(address(vault)), 0, "vault has NO rewards");
    }

    /*
     FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt test_vaults_rewards_onDeposit -vv
    */
    function test_vaults_rewards_onDeposit() public {
        vm.prank(OWNER);
        vaultIncentivesModule.addNotificationReceiver(INotificationReceiver(address(vaultIncentivesController)));

        SiloIncentivesControllerCL cl = new SiloIncentivesControllerCL(
            address(vaultIncentivesController), address(siloIncentivesController)
        );

        vm.prank(OWNER);
        vaultIncentivesModule.addIncentivesClaimingLogic(address(silo1), cl);

        uint256 rewardsPerSec = 3210;

        // standard program for silo users
        siloIncentivesController.createIncentivesProgram(DistributionTypes.IncentivesProgramCreationInput({
            name: "x",
            rewardToken: address(reward1),
            emissionPerSecond: uint104(rewardsPerSec),
            distributionEnd: uint40(block.timestamp + 10)
        }));

        uint256 depositAmount = 2e8;
        uint256 shares = depositAmount * SiloMathLib._DECIMALS_OFFSET_POW;
        uint256 sharesCapped = depositAmount > _cap() ? _cap() * SiloMathLib._DECIMALS_OFFSET_POW : shares;

        vm.expectCall(
            address(siloIncentivesController),
            abi.encodeWithSelector(
                INotificationReceiver.afterTokenTransfer.selector,
                address(0),
                0,
                address(vault),
                sharesCapped,
                sharesCapped,
                sharesCapped
            )
        );

        vm.expectCall(
            address(vaultIncentivesController),
            abi.encodeWithSelector(
                INotificationReceiver.afterTokenTransfer.selector,
                address(0),
                0,
                address(this),
                depositAmount,
                depositAmount,
                depositAmount
            )
        );

        vault.deposit(depositAmount, address(this));
        assertEq(silo1.totalSupply(), sharesCapped, "we expect deposit to go to silo1");

        vm.warp(block.timestamp + 1);
        string memory programName = Strings.toHexString(address(reward1));

        assertEq(
            siloIncentivesController.getRewardsBalance(address(vault), "x"),
            rewardsPerSec,
            "expected rewards for silo after 1s"
        );

        assertEq(
            vaultIncentivesController.getRewardsBalance(address(this), programName),
            0,
            "expected ZERO rewards, because they are generated BEFORE deposit"
        );

        // do another deposit, it will distribute
        vm.prank(address(1));
        vault.deposit(1e20, address(1));

        assertEq(
            vaultIncentivesController.getRewardsBalance(address(this), programName),
            rewardsPerSec,
            "expected ALL rewards to go to first depositor"
        );

        vaultIncentivesController.claimRewards(address(this));
        assertEq(reward1.balanceOf(address(this)), rewardsPerSec, "claimed rewards");

        assertEq(
            siloIncentivesController.getRewardsBalance(address(vault), "x"),
            0,
            "rewards for silo claimed"
        );

        assertEq(
            vaultIncentivesController.getRewardsBalance(address(this), programName),
            0,
            "rewards for vault claimed"
        );
    }

    /*
     FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt test_vaults_rewards_calculations -vv
    */
    function test_vaults_rewards_calculations() public {
        vm.prank(OWNER);
        vaultIncentivesModule.addNotificationReceiver(INotificationReceiver(address(vaultIncentivesController)));

        SiloIncentivesControllerCL cl = new SiloIncentivesControllerCL(
            address(vaultIncentivesController), address(siloIncentivesController)
        );

        vm.prank(OWNER);
        vaultIncentivesModule.addIncentivesClaimingLogic(address(silo1), cl);

        uint256 rewardsPerSec = 3210;

        // standard program for silo users
        siloIncentivesController.createIncentivesProgram(DistributionTypes.IncentivesProgramCreationInput({
            name: "x",
            rewardToken: address(reward1),
            emissionPerSecond: uint104(rewardsPerSec),
            distributionEnd: uint40(block.timestamp + 10)
        }));

        uint256 depositAmount = 2e8;
        string memory programName = Strings.toHexString(address(reward1));

        vault.deposit(depositAmount, address(this));

        assertEq(
            vaultIncentivesController.getRewardsBalance(address(this), programName),
            0,
            "expected ZERO rewards, because they are generated BEFORE deposit"
        );

        vault.claimRewards();

        assertEq(
            vaultIncentivesController.getRewardsBalance(address(this), programName),
            0,
            "claimRewards will not generate any rewards, because incentives state was calculated before user deposit"
        );

        vault.withdraw(depositAmount / 2, address(this), address(this));

        assertEq(
            vaultIncentivesController.getRewardsBalance(address(this), programName),
            0,
            "rewards should not be generated by withdraw"
        );

        vm.warp(block.timestamp + 1);
        vault.claimRewards();

        assertEq(
            vaultIncentivesController.getRewardsBalance(address(this), programName),
            rewardsPerSec,
            "1s when additional time pass getRewardsBalance returns rewards to claim"
        );

        vm.warp(block.timestamp + 1);
        vault.claimRewards();

        assertEq(
            vaultIncentivesController.getRewardsBalance(address(this), programName),
            rewardsPerSec * 2,
            "2s when additional time pass getRewardsBalance returns rewards to claim"
        );

        vaultIncentivesController.claimRewards(address(this));
        assertEq(reward1.balanceOf(address(this)), rewardsPerSec * 2, "claimed rewards");
    }
}
