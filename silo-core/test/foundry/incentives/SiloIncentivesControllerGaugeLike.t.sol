// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {ERC20Mock} from "openzeppelin5/mocks/token/ERC20Mock.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";
import {GaugeHookReceiver} from "silo-core/contracts/utils/hook-receivers/gauge/GaugeHookReceiver.sol";
import {IGaugeHookReceiver} from "silo-core/contracts/interfaces/IGaugeHookReceiver.sol";
import {SiloLittleHelper} from "silo-core/test/foundry/_common/SiloLittleHelper.sol";
import {IGaugeLike as IGauge} from "silo-core/contracts/interfaces/IGaugeLike.sol";
import {SiloIncentivesControllerGaugeLike} from "silo-core/contracts/incentives/SiloIncentivesControllerGaugeLike.sol";

import {
    SiloIncentivesControllerGaugeLikeFactoryDeploy
} from "silo-core/deploy/SiloIncentivesControllerGaugeLikeFactoryDeploy.sol";
import {
    ISiloIncentivesControllerGaugeLikeFactory
} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesControllerGaugeLikeFactory.sol";

/**
    FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc SiloIncentivesControllerGaugeLikeTest
 */
contract SiloIncentivesControllerGaugeLikeTest is SiloLittleHelper, Test {
    address internal _shareToken = address(new ERC20Mock());
    address internal _owner = makeAddr("Owner");
    address internal _notifier = address(new ERC20Mock());

    ISiloIncentivesControllerGaugeLikeFactory internal _factory;

    event GaugeKilled();
    event GaugeUnKilled();

    function setUp() public {
        SiloIncentivesControllerGaugeLikeFactoryDeploy deploy = new SiloIncentivesControllerGaugeLikeFactoryDeploy();
        deploy.disableDeploymentsSync();
        _factory = ISiloIncentivesControllerGaugeLikeFactory(deploy.run());
    }

    /**
     FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_createGaugeLike
     */
    function test_createGaugeLike_success() public {
        address gaugeLike = _factory.createGaugeLike(_owner, _notifier, _shareToken);
        assertTrue(_factory.createdInFactory(gaugeLike), "GaugeLike should be created in factory");
    }

    /**
     FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_createGaugeLike_zeroShares
     */
    function test_createGaugeLike_zeroShares() public {
        vm.expectRevert(IGauge.EmptyShareToken.selector);
        _factory.createGaugeLike(_owner, _notifier, address(0));
    }

    /**
     FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_killGauge_onlyOwner
     */
    function test_killGauge_onlyOwner() public {
        address gaugeLike = _factory.createGaugeLike(_owner, _notifier, _shareToken);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        IGauge(gaugeLike).killGauge();
    }

    /**
     FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_unKillGauge_onlyOwner
     */
    function test_unKillGauge_onlyOwner() public {
        address gaugeLike = _factory.createGaugeLike(_owner, _notifier, _shareToken);

        vm.prank(_owner);
        IGauge(gaugeLike).killGauge();

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        IGauge(gaugeLike).unkillGauge();
    }

    /**
     FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_killGauge_success
     */
    function test_killGauge_success() public {
        address gaugeLike = _factory.createGaugeLike(_owner, _notifier, _shareToken);

        assertFalse(IGauge(gaugeLike).is_killed(), "GaugeLike should not be killed");

        vm.expectEmit(true, true, true, true);
        emit GaugeKilled();

        vm.prank(_owner);
        IGauge(gaugeLike).killGauge();

        assertTrue(IGauge(gaugeLike).is_killed(), "GaugeLike should be killed");
    }

    /**
     FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_unKillGauge_success
     */
    function test_unKillGauge_success() public {
        address gaugeLike = _factory.createGaugeLike(_owner, _notifier, _shareToken);

        vm.prank(_owner);
        IGauge(gaugeLike).killGauge();

        assertTrue(IGauge(gaugeLike).is_killed(), "GaugeLike should be killed");

        vm.expectEmit(true, true, true, true);
        emit GaugeUnKilled();

        vm.prank(_owner);
        IGauge(gaugeLike).unkillGauge();

        assertFalse(IGauge(gaugeLike).is_killed(), "GaugeLike should not be killed");
    }

    /**
     FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_gaugeLikeIncentives_with_gaugeHookReceiver
     */
    function test_gaugeLikeIncentives_with_gaugeHookReceiver() public {
        address timelock = makeAddr("Timelock");
        address feeDistributor = makeAddr("FeeDistributor");

        // Mock addresses that we need for the `SiloFactoryDeploy` script
        AddrLib.setAddress(VeSiloContracts.TIMELOCK_CONTROLLER, timelock);
        AddrLib.setAddress(VeSiloContracts.FEE_DISTRIBUTOR, feeDistributor);

        ISiloConfig siloConfig = _setUpLocalFixture(SiloConfigsNames.SILO_LOCAL_GAUGE_HOOK_RECEIVER);
        (address silo0,) = siloConfig.getSilos();

        IGaugeHookReceiver gaugeHookReceiver = IGaugeHookReceiver(IShareToken(address(silo0)).hookSetup().hookReceiver);
        (,address shareCollateralToken,) = siloConfig.getShareTokens(silo0);

        address gaugeLikeController = _factory.createGaugeLike(_owner, _notifier, shareCollateralToken);

        vm.prank(timelock);
        gaugeHookReceiver.setGauge(IGauge(gaugeLikeController), IShareToken(shareCollateralToken));

        IGauge configured = GaugeHookReceiver(address(gaugeHookReceiver)).configuredGauges(
            IShareToken(shareCollateralToken)
        );

        assertEq(address(configured), address(gaugeLikeController));
    }
}
