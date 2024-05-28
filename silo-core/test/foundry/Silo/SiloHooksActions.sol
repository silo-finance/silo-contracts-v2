// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";

import {HookReceiverMock} from "silo-core/test/foundry/_mocks/HookReceiverMock.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISiloDeployer} from "silo-core/contracts/interfaces/ISiloDeployer.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {SiloFixtureWithFeeDistributor as SiloFixture} from "../_common/fixtures/SiloFixtureWithFeeDistributor.sol";
import {SiloConfigOverride} from "../_common/fixtures/SiloFixture.sol";
import {MintableToken} from "../_common/MintableToken.sol";
import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/// FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mc SiloHooksActions
contract SiloHooksActions is SiloLittleHelper, Test {
    SiloFixture internal _siloFixture;
    ISiloConfig internal _siloConfig;

    address internal timelock = makeAddr("Timelock");
    address internal feeDistributor = makeAddr("FeeDistributor");

    function setUp() public {
        // Mock addresses that we need for the `SiloFactoryDeploy` script
        AddrLib.setAddress(VeSiloContracts.TIMELOCK_CONTROLLER, timelock);
        AddrLib.setAddress(VeSiloContracts.FEE_DISTRIBUTOR, feeDistributor);
    }

    /// FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testDepositFnHooksActions
    function testDepositFnHooksActions() public {
        (ISiloConfig siloConfig, ISilo silo0, ISilo silo1) = deploySiloWithHook(address(0));

        IERC20 token0 = IERC20(silo0.config().token0());
        IERC20 token1 = IERC20(silo0.config().token1());

        uint256 amount = 1e18;

        token0.approve(address(silo0), amount);
        token1.approve(address(silo1), amount);

        silo0.deposit(amount);
        silo1.deposit(amount);

        assertTrue(_hookReceiverMock.beforeDepositCalled(), "beforeDeposit hook was not called");
        assertTrue(_hookReceiverMock.afterDepositCalled(), "afterDeposit hook was not called");
    }

    function deploySiloWithHook(address _hookReceiver)
        internal
        returns (ISiloConfig siloConfig, ISilo silo0, ISilo silo1)
    {
        _siloFixture = new SiloFixture();
        SiloConfigOverride memory configOverride;

        configOverride.token0 = address(new MintableToken(18));
        configOverride.token1 = address(new MintableToken(18));
        configOverride.hookReceiver = _hookReceiver;
        configOverride.configName = SiloConfigsNames.LOCAL_DEPLOYER;

        (siloConfig, silo0, silo1,,,) = _siloFixture.deploy_local(configOverride);

        __init(MintableToken(configOverride.token0), MintableToken(configOverride.token1), silo0, silo1);
    }
}
