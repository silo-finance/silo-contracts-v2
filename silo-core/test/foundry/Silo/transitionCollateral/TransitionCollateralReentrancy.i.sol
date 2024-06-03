// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISiloDeployer} from "silo-core/contracts/interfaces/ISiloDeployer.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";

import {SiloConfigOverride} from "../../_common/fixtures/SiloFixture.sol";
import {SiloFixtureWithFeeDistributor as SiloFixture} from "../../_common/fixtures/SiloFixtureWithFeeDistributor.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";
import {MintableToken} from "../../_common/MintableToken.sol";
import {HookReceiverMock} from "../../_mocks/HookReceiverMock.sol";

/*
FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mc TransitionCollateralReentrancyTest
*/
contract TransitionCollateralReentrancyTest is SiloLittleHelper, Test, IHookReceiver {
    using Hook for uint256;

    bool afterActionExecuted;

    function setUp() public {
        SiloFixture siloFixture = new SiloFixture();
        SiloConfigOverride memory configOverride;

        token0 = new MintableToken(6);
        token1 = new MintableToken(7);
        configOverride.token0 = address(token0);
        configOverride.token1 = address(token1);
        configOverride.hookReceiver = address(this);
        configOverride.configName = SiloConfigsNames.LOCAL_DEPLOYER;

        (, silo0, silo1,,, partialLiquidation) = siloFixture.deploy_local(configOverride);

        silo0.updateHooks();
    }

    function hookReceiverConfig(address _silo) external view returns (uint24 hooksBefore, uint24 hooksAfter) {
        hooksBefore = 0;
        hooksAfter = _silo == address(silo0) ? uint24(Hook.COLLATERAL_TOKEN | Hook.SHARE_TOKEN_TRANSFER) : 0;
    }

    function initialize(ISiloConfig, bytes calldata) external pure {
        // nothing to do here
    }

    function beforeAction(address, uint256, bytes calldata) external pure {
        revert("not in use");
    }

    function afterAction(address _silo, uint256 _action, bytes calldata _input) external {
        assertEq(_silo, address(silo0), "hook setup is only for silo0");
        assertTrue(_action.matchAction(Hook.COLLATERAL_TOKEN | Hook.SHARE_TOKEN_TRANSFER), "hook setup is only for share transfer");

        Hook.AfterTokenTransfer memory input = Hook.afterTokenTransferDecode(_input);
        address borrower = input.sender;

        if (silo0.isSolvent(borrower)) return;

        afterActionExecuted = true;
        address siloWithDebt = address(silo1);

        (
            uint256 collateralToLiquidate, uint256 debtToRepay
        ) = partialLiquidation.maxLiquidation(siloWithDebt, borrower);

        assertEq(collateralToLiquidate, 5, "collateralToLiquidate");
        assertEq(debtToRepay, 5, "debtToRepay");

        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        partialLiquidation.liquidationCall(
            siloWithDebt,
            address(token0),
            address(token1),
            borrower,
            debtToRepay,
            false
        );
    }

    function test_transitionCollateral2protected_liquidationReverts() public {
        address borrower = makeAddr("borrower");
        bool sameAsset;

        _depositForBorrow(5, makeAddr("depositor"));
        uint256 depositedShares = _deposit(10, borrower);
        _borrow(5, borrower, sameAsset);

        vm.prank(borrower);
        silo0.transitionCollateral(depositedShares / 2, borrower, ISilo.CollateralType.Collateral);

        assertTrue(afterActionExecuted, "afterActionExecuted");
        assertTrue(silo0.isSolvent(borrower), "borrower is solvent after transition of collateral");
    }
}
