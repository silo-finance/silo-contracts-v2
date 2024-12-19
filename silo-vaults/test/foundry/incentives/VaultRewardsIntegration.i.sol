// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {Ownable} from "openzeppelin5/access/Ownable2Step.sol";

import {SiloIncentivesController} from "silo-core/contracts/incentives/SiloIncentivesController.sol";
import {MintableToken} from "silo-core/test/foundry/_common/MintableToken.sol";
import {DistributionTypes} from "silo-core/contracts/incentives/lib/DistributionTypes.sol";
import {IGaugeHookReceiver} from "silo-core/contracts/interfaces/IGaugeHookReceiver.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IGaugeLike} from "silo-core/contracts/interfaces/IGaugeLike.sol";

import {ErrorsLib} from "../../../contracts/libraries/ErrorsLib.sol";

import {INotificationReceiver} from "../../../contracts/interfaces/INotificationReceiver.sol";
import {IVaultIncentivesModule} from "../../../contracts/interfaces/IVaultIncentivesModule.sol";
import {IntegrationTest} from "../helpers/IntegrationTest.sol";
import {NB_MARKETS, CAP, MIN_TEST_ASSETS, MAX_TEST_ASSETS} from "../helpers/BaseTest.sol";

contract GaugeLike is SiloIncentivesController, IGaugeLike {
    constructor(address _owner, address _notifier) SiloIncentivesController(_owner, _notifier) {}

    function afterTokenTransfer(
        address _sender,
        uint256 _senderBalance,
        address _recipient,
        uint256 _recipientBalance,
        uint256 _totalSupply,
        uint256 _amount
    ) public override(SiloIncentivesController, IGaugeLike) {
        // duplicated code
        super.afterTokenTransfer(_sender, _senderBalance, _recipient, _recipientBalance, _totalSupply, _amount);
    }

    function share_token() external view returns (address) {
        return NOTIFIER;
    }

    function is_killed() external view returns (bool) {
        return false;
    }
}

/*
 FOUNDRY_PROFILE=vaults-tests forge test --ffi --mc MetaMorphoIncentivesTest -vvv
*/
contract VaultRewardsIntegrationTest is IntegrationTest {
    MintableToken reward1 = new MintableToken(18);
    MintableToken reward2 = new MintableToken(18);

    SiloIncentivesController siloIncentivesController;
    SiloIncentivesController vaultIncentivesController;

    function setUp() public override {
        super.setUp();

        _setCap(allMarkets[0], CAP);
        _setCap(allMarkets[1], CAP);
        _setCap(allMarkets[2], CAP);

        reward1.setOnDemand(true);
        reward2.setOnDemand(true);
    }

    /*
     FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt test_vaults_gauge_deposit_noHookSetup -vv
    */
    function test_vaults_gauge_deposit_noHookSetup() public {
        // TODO add test when notifier will be wrong and expect no rewards (or revert?)
        vaultIncentivesController = new SiloIncentivesController(address(this), address(vault));

        // SiloIncentivesController is per silo
        siloIncentivesController = new GaugeLike(address(this), address(silo0));

        // set SiloIncentivesController as gauge for hook
        vm.prank(Ownable(address(partialLiquidation)).owner());
        IGaugeHookReceiver(address(partialLiquidation)).setGauge(
            IGaugeLike(address(siloIncentivesController)), IShareToken(address(silo0))
        );

        assertTrue(address(vault.INCENTIVES_MODULE()) != address(0), "INCENTIVES_MODULE");

//        vm.expectCall(
//            address(vault.INCENTIVES_MODULE()),
//            abi.encodeWithSelector(IVaultIncentivesModule.getAllIncentivesClaimingLogics.selector)
//        );
//
//        vm.expectCall(
//            address(vault.INCENTIVES_MODULE()),
//            abi.encodeWithSelector(IVaultIncentivesModule.getNotificationReceivers.selector)
//        );

        // does not revert without incentives setup
        vault.deposit(1, address(this));

        // does not revert without incentives setup:

//        vault.claimRewards();
//        vaultIncentivesController.claimRewards(address(this));
//        siloIncentivesController.claimRewards(address(this));
    }

    /*
     FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt test_vaults_incentives_immediateDistribution -vv
    */
    function test_vaults_incentives_immediateDistribution() public {
        address user = makeAddr("user");

        uint256 rewardsPerSec = 3;

        // and add immediate distribution

        vm.prank(OWNER);
        vaultIncentivesModule.addNotificationReceiver(INotificationReceiver(address(vaultIncentivesController)));

        // this call is expected on depositing
        vm.expectCall(
            address(vaultIncentivesController),
            abi.encodeWithSelector(
                INotificationReceiver.afterTokenTransfer.selector,
                address(0),
                0,
                user,
                1,
                1,
                1
            )
        );

        // does not revert without incentives setup
        vm.prank(user);
        vault.deposit(1, user);

        vm.warp(block.timestamp + 1);

        assertEq(vaultIncentivesController.getRewardsBalance(user, "x"), rewardsPerSec, "expected reward after 1s");

        vm.prank(user);
        vaultIncentivesController.claimRewards(user);

        assertEq(reward1.balanceOf(user), rewardsPerSec, "user can claim standard reward");
    }

//    function _createNewMarket() public virtual {
//        // for deploying just new silo.
//        SiloFixture siloFixture = new SiloFixtureWithVeSilo();
//        SiloConfigOverride memory _override;
//
//        _override.token0 = address(collateralToken);
//        _override.token1 = address(loanToken);
//        _override.configName = SiloConfigsNames.LOCAL_VAULT_INCENTIVES;
//        _override.hook = new HookContractForTesting();
//
//        (, silo0, silo1,,,) = siloFixture.deploy_local(_override);
//        vm.label(address(silo0), string.concat("Market#0_withRewards"));
//
//        // NOTICE: overriding default market on position #0
//        allMarkets[0] = silo1;
//        collateralMarkets[silo1] = silo0;
//
//        _setCap(allMarkets[0], type(uint184).max);
//    }
}
