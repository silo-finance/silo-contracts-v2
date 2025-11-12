// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";
import {Clones} from "openzeppelin5/proxy/Clones.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";


import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {IPartialLiquidationByDefaulting} from "silo-core/contracts/interfaces/IPartialLiquidationByDefaulting.sol";
import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";
import {IGaugeHookReceiver} from "silo-core/contracts/interfaces/IGaugeHookReceiver.sol";

import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";
import {SiloConfigOverride, SiloFixture} from "../../_common/fixtures/SiloFixture.sol";
import {MintableToken} from "silo-core/test/foundry/_common/MintableToken.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {SiloIncentivesController} from "silo-core/contracts/incentives/SiloIncentivesController.sol";

import {DummyOracle} from "silo-core/test/foundry/_common/DummyOracle.sol";
import {SiloHookV2} from "silo-core/contracts/hooks/SiloHookV2.sol";

/*
FOUNDRY_PROFILE=core_test forge test --ffi --mc DefaultingLiquidation_IncentiveControllerSetupTest -vv
*/
contract DefaultingLiquidation_IncentiveControllerSetupTest is Test {
    ISiloConfig siloConfig = ISiloConfig(makeAddr("siloConfig"));
    address silo0 = makeAddr("silo0");
    address silo1 = makeAddr("silo1");

    address collateralShareToken = silo0;
    address protectedShareToken = makeAddr("protectedShareToken");
    address debtShareToken = makeAddr("debtShareToken");

    SiloHookV2 defaulting;
    ISiloIncentivesController gauge;

    function setUp() public view {
        require(silo0 == collateralShareToken, "silo0 must be collateralShareToken");
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_validateControllerForCollateral_EmptyCollateralShareToken -vv
    */
    function test_validateControllerForCollateral_EmptyCollateralShareToken() public {
        ISiloConfig.ConfigData memory config;
        defaulting = _cloneHook(config);

        vm.mockCall(
            address(siloConfig),
            abi.encodeWithSelector(ISiloConfig.getShareTokens.selector, silo0),
            abi.encode(address(0), address(0), address(0))
        );

        vm.expectRevert(IPartialLiquidationByDefaulting.EmptyCollateralShareToken.selector);
        defaulting.validateControllerForCollateral(silo0);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_validateControllerForCollateral_NoControllerForCollateral -vv
    */
    function test_validateControllerForCollateral_NoControllerForCollateral() public {
        ISiloConfig.ConfigData memory config;
        defaulting = _cloneHook(config);

        _mockGetShareTokens();

        vm.expectRevert(IPartialLiquidationByDefaulting.NoControllerForCollateral.selector);
        defaulting.validateControllerForCollateral(silo0);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_validateControllerForCollateral_pass -vv
    */
    function test_validateControllerForCollateral_pass() public {
        ISiloConfig.ConfigData memory config;
        defaulting = _cloneHook(config);

        _mockGetShareTokens();

        gauge = new SiloIncentivesController(address(this), address(defaulting), collateralShareToken);

        _setGauge(gauge, collateralShareToken);

        defaulting.validateControllerForCollateral(silo0);
    }
    
    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_validateControllerForCollateral_revertsWhenShareTokenDoesNotMatch -vv
    */
    function test_validateControllerForCollateral_revertsWhenShareTokenDoesNotMatch() public {
        ISiloConfig.ConfigData memory config;
        defaulting = _cloneHook(config);

        _mockGetShareTokens();

        gauge = new SiloIncentivesController(address(this), address(defaulting), collateralShareToken);
        _setGauge(gauge, collateralShareToken);

        vm.expectRevert(IPartialLiquidationByDefaulting.NoControllerForCollateral.selector);
        defaulting.validateControllerForCollateral(silo1);

        vm.expectRevert();
        defaulting.validateControllerForCollateral(protectedShareToken);

        vm.expectRevert();
        defaulting.validateControllerForCollateral(debtShareToken);
    }

    function _setGauge(ISiloIncentivesController _gauge, address _collateralShareToken) internal {
        address owner = Ownable(address(defaulting)).owner();
        vm.prank(owner);
        IGaugeHookReceiver(address(defaulting)).setGauge(_gauge, IShareToken(_collateralShareToken));
    }

    function _cloneHook(ISiloConfig.ConfigData memory _config) internal returns (SiloHookV2 defaulting) {
        SiloHookV2 implementation = new SiloHookV2();
        defaulting = SiloHookV2(Clones.clone(address(implementation)));

        _mockSiloConfig(_config, _config);

        defaulting.initialize(siloConfig, abi.encode(address(this)));
    }

    function _mockGetShareTokens() internal {
         vm.mockCall(
            address(siloConfig),
            abi.encodeWithSelector(ISiloConfig.getShareTokens.selector, silo0),
            abi.encode(protectedShareToken, collateralShareToken, debtShareToken)
        );

        vm.mockCall(
            address(siloConfig),
            abi.encodeWithSelector(ISiloConfig.getShareTokens.selector, silo1),
            abi.encode(makeAddr("protectedShareToken1"), makeAddr("collateralShareToken1"), makeAddr("debtShareToken1"))
        );
    }

    function _mockSiloConfig(ISiloConfig.ConfigData memory _config0, ISiloConfig.ConfigData memory _config1) internal {
        vm.mockCall(
            address(siloConfig), abi.encodeWithSelector(ISiloConfig.getSilos.selector), abi.encode(silo0, silo1)
        );

        vm.mockCall(
            address(siloConfig), abi.encodeWithSelector(ISiloConfig.getConfig.selector, silo0), abi.encode(_config0)
        );

        vm.mockCall(
            address(siloConfig), abi.encodeWithSelector(ISiloConfig.getConfig.selector, silo1), abi.encode(_config1)
        );

        vm.mockCall(
            collateralShareToken, abi.encodeWithSelector(IShareToken.silo.selector), abi.encode(silo0)
        );

        vm.mockCall(
            protectedShareToken, abi.encodeWithSelector(IShareToken.silo.selector), abi.encode(silo0)
        );

        vm.mockCall(
            debtShareToken, abi.encodeWithSelector(IShareToken.silo.selector), abi.encode(silo0)
        );
    }
}
