// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {Actions} from "silo-core/contracts/lib/Actions.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IInterestRateModel} from "silo-core/contracts/interfaces/IInterestRateModel.sol";

import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
 FOUNDRY_PROFILE=core-test forge test -vv --mc ActionsInitializeTest --ffi
*/
contract ActionsInitializeTest is Test, SiloLittleHelper {
    ISiloConfig siloConfig;

    function setUp() public {
        siloConfig = _setUpLocalFixture();
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vv --mt test_actions_initialize_WrongSilo --ffi
    */
    function test_actions_initialize_WrongSilo() public {
        address irmConfigAddress = makeAddr("irmConfigAddress");

        vm.expectRevert(ISiloConfig.WrongSilo.selector);
        Actions.initialize(siloConfig, irmConfigAddress);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vv --mt test_actions_initialize_pass --ffi
    */
    function test_actions_initialize_pass() public {
        address irmConfigAddress = makeAddr("irmConfigAddress");

        ISiloConfig.ConfigData memory mockedCfg = siloConfig.getConfig(address(silo0));

        assertEq(address(_getShareTokenStorage().siloConfig), address(0), "storage.siloConfig is empty before init");

        // we have to mock it, so it will not throw with WrongSilo()
        vm.mockCall(address(siloConfig), abi.encodeWithSelector(ISiloConfig.getConfig.selector, address(this)), abi.encode(mockedCfg));

        // we expecting to connect IRM config on init
        vm.expectCall(
            mockedCfg.interestRateModel,
            abi.encodeWithSelector(IInterestRateModel.connect.selector, irmConfigAddress)
        );

        address hook = Actions.initialize(siloConfig, irmConfigAddress);

        assertEq(hook, mockedCfg.hookReceiver, "hookReceiver match");
        assertEq(address(_getShareTokenStorage().siloConfig), address(siloConfig), "siloConfig set");
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vv --mt test_actions_initialize_SiloInitialized --ffi
    */
    function test_actions_initialize_SiloInitialized() public {
        address irmConfigAddress = makeAddr("irmConfigAddress");
        Actions.initialize(siloConfig, irmConfigAddress);

        vm.expectRevert(ISilo.SiloInitialized.selector);
        Actions.initialize(siloConfig, irmConfigAddress);
    }
}
