// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {ERC20Mock} from "openzeppelin5/mocks/token/ERC20Mock.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {SiloIncentivesControllerGaugeLike} from "silo-core/contracts/incentives/SiloIncentivesControllerGaugeLike.sol";
import {
    ISiloIncentivesControllerGaugeLike
} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesControllerGaugeLike.sol";
import {
    SiloIncentivesControllerGaugeLikeFactoryDeploy
} from "silo-core/deploy/SiloIncentivesControllerGaugeLikeFactoryDeploy.sol";
import {
    ISiloIncentivesControllerGaugeLikeFactory
} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesControllerGaugeLikeFactory.sol";

/**
    FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc SiloIncentivesControllerGaugeLikeTest
 */
contract SiloIncentivesControllerGaugeLikeTest is Test {
    address internal _shareToken = address(new ERC20Mock());
    address internal _owner = makeAddr("Owner");
    address internal _notifier = address(new ERC20Mock());

    ISiloIncentivesControllerGaugeLikeFactory internal _factory;

    event GaugeKilled();
    event GaugeUnkilled();

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
     FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_killGauge_onlyOwner
     */
    function test_killGauge_onlyOwner() public {
        address gaugeLike = _factory.createGaugeLike(_owner, _notifier, _shareToken);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        ISiloIncentivesControllerGaugeLike(gaugeLike).killGauge();
    }

    /**
     FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_unKillGauge_onlyOwner
     */
    function test_unKillGauge_onlyOwner() public {
        address gaugeLike = _factory.createGaugeLike(_owner, _notifier, _shareToken);

        vm.prank(_owner);
        ISiloIncentivesControllerGaugeLike(gaugeLike).killGauge();

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        ISiloIncentivesControllerGaugeLike(gaugeLike).unkillGauge();
    }

    /**
     FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_killGauge_success
     */
    function test_killGauge_success() public {
        address gaugeLike = _factory.createGaugeLike(_owner, _notifier, _shareToken);

        assertFalse(ISiloIncentivesControllerGaugeLike(gaugeLike).is_killed(), "GaugeLike should not be killed");

        vm.expectEmit(true, true, true, true);
        emit GaugeKilled();

        vm.prank(_owner);
        ISiloIncentivesControllerGaugeLike(gaugeLike).killGauge();

        assertTrue(ISiloIncentivesControllerGaugeLike(gaugeLike).is_killed(), "GaugeLike should be killed");
    }

    /**
     FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_unKillGauge_success
     */
    function test_unKillGauge_success() public {
        address gaugeLike = _factory.createGaugeLike(_owner, _notifier, _shareToken);

        vm.prank(_owner);
        ISiloIncentivesControllerGaugeLike(gaugeLike).killGauge();

        assertTrue(ISiloIncentivesControllerGaugeLike(gaugeLike).is_killed(), "GaugeLike should be killed");

        vm.expectEmit(true, true, true, true);
        emit GaugeUnkilled();

        vm.prank(_owner);
        ISiloIncentivesControllerGaugeLike(gaugeLike).unkillGauge();

        assertFalse(ISiloIncentivesControllerGaugeLike(gaugeLike).is_killed(), "GaugeLike should not be killed");
    }
}
