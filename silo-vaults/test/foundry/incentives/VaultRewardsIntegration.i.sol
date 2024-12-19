// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {Ownable} from "openzeppelin5/access/Ownable2Step.sol";

import {SiloIncentivesController} from "silo-core/contracts/incentives/SiloIncentivesController.sol";
import {SiloIncentivesControllerGaugeLike} from "silo-core/contracts/incentives/SiloIncentivesControllerGaugeLike.sol";
import {MintableToken} from "silo-core/test/foundry/_common/MintableToken.sol";
import {DistributionTypes} from "silo-core/contracts/incentives/lib/DistributionTypes.sol";
import {IGaugeHookReceiver} from "silo-core/contracts/interfaces/IGaugeHookReceiver.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IGaugeLike} from "silo-core/contracts/interfaces/IGaugeLike.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {SiloMathLib} from "silo-core/contracts/lib/SiloMathLib.sol";

import {ErrorsLib} from "../../../contracts/libraries/ErrorsLib.sol";

import {INotificationReceiver} from "../../../contracts/interfaces/INotificationReceiver.sol";
import {IVaultIncentivesModule} from "../../../contracts/interfaces/IVaultIncentivesModule.sol";
import {IntegrationTest} from "../helpers/IntegrationTest.sol";
import {NB_MARKETS, CAP, MIN_TEST_ASSETS, MAX_TEST_ASSETS} from "../helpers/BaseTest.sol";

/*
 FOUNDRY_PROFILE=vaults-tests forge test --ffi --mc MetaMorphoIncentivesTest -vvv
*/
contract VaultRewardsIntegrationTest is IntegrationTest {
    MintableToken reward1 = new MintableToken(18);

    SiloIncentivesControllerGaugeLike siloIncentivesController;
    SiloIncentivesController vaultIncentivesController;

    function setUp() public override {
        super.setUp();

        _setCap(allMarkets[0], CAP);
        _setCap(allMarkets[1], CAP);
        _setCap(allMarkets[2], CAP);

        reward1.setOnDemand(true);

        vaultIncentivesController = new SiloIncentivesController(address(this), address(vault));

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

    /*
     FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt test_vaults_gauge_deposit_noRewards -vv
    */
    function test_vaults_gauge_deposit_noRewards() public {
        uint256 amount = 1e18;
        uint256 shares = amount * SiloMathLib._DECIMALS_OFFSET_POW;

        vm.expectCall(
            address(partialLiquidation),
            abi.encodeWithSelector(
                IHookReceiver.afterAction.selector,
                address(silo1),
                Hook.COLLATERAL_TOKEN | Hook.SHARE_TOKEN_TRANSFER,
                hex"00000000000000000000000000000000000000001d1499e622d69689cdf9004d05ec547d650ff21100000000000000000000000000000000000000000000003635c9adc5dea00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003635c9adc5dea0000000000000000000000000000000000000000000000000003635c9adc5dea00000"
            )
        );

        vault.deposit(amount, address(this));
        assertEq(silo1.totalSupply(), shares, "we expect deposit to go to silo");

        // does not revert without incentives setup:

        vault.claimRewards();
        siloIncentivesController.claimRewards(address(this));

        assertEq(reward1.balanceOf(address(vault)), 0, "vault has NO rewards");
    }

    /*
     FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt test_vaults_gauge_deposit_withRewards -vv
    */
    function test_vaults_gauge_deposit_withRewards() public {
        vm.prank(OWNER);
        vaultIncentivesModule.addNotificationReceiver(INotificationReceiver(address(vaultIncentivesController)));

        uint256 rewardsPerSec = 3;

        // standard program for silo users
        siloIncentivesController.createIncentivesProgram(DistributionTypes.IncentivesProgramCreationInput({
            name: "x",
            rewardToken: address(reward1),
            emissionPerSecond: uint104(rewardsPerSec),
            distributionEnd: uint40(block.timestamp + 10)
        }));

        uint256 amount = 1e18;
        uint256 shares = amount * SiloMathLib._DECIMALS_OFFSET_POW;

        vault.deposit(amount, address(this));
        assertEq(silo1.totalSupply(), shares, "we expect deposit to go to silo");

        vm.warp(block.timestamp + 1);
        assertEq(siloIncentivesController.getRewardsBalance(address(vault), "x"), rewardsPerSec, "expected reward after 1s");

        // TODO add claiming logic

        vault.claimRewards();
        siloIncentivesController.claimRewards(address(this));

        assertEq(reward1.balanceOf(address(vault)), 1, "vault got rewards");
    }
}
