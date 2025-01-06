// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {SiloRouterDeploy} from "silo-core/deploy/SiloRouterDeploy.s.sol";
import {SiloRouter} from "silo-core/contracts/SiloRouter.sol";
import {SiloDeployments, SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IWrappedNativeToken} from "silo-core/contracts/interfaces/IWrappedNativeToken.sol";
import {ShareTokenDecimalsPowLib} from "../_common/ShareTokenDecimalsPowLib.sol";

// solhint-disable function-max-lines

// FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc SiloRouterActionsTest
contract SiloRouterActionsTest is IntegrationTest {
    using ShareTokenDecimalsPowLib for uint256;

    uint256 internal constant _FORKING_BLOCK_NUMBER = 267182500;
    uint256 internal constant _ETH_BALANCE = 10e18;
    uint256 internal constant _TOKEN0_AMOUNT = 100e18;
    uint256 internal constant _TOKEN1_AMOUNT = 100e6;

    address public silo0;
    address public silo1;
    address public token0; // weth
    address public token1; // usdc

    address public depositor = makeAddr("Depositor");
    address public borrower = makeAddr("Borrower");

    address public wethWhale = 0x70d95587d40A2caf56bd97485aB3Eec10Bee6336;
    address public usdcWhale = 0xa0E9B6DA89BD0303A8163B81B8702388bE0Fde77;

    address public collateralToken0;
    address public protectedToken0;
    address public debtToken0;

    address public collateralToken1;
    address public protectedToken1;
    address public debtToken1;

    SiloRouter public router;

    function setUp() public {
        vm.createSelectFork(
            getChainRpcUrl(ARBITRUM_ONE_ALIAS),
            _FORKING_BLOCK_NUMBER
        );

        SiloRouterDeploy deploy = new SiloRouterDeploy();
        deploy.disableDeploymentsSync();

        router = deploy.run();

        address siloConfig = 0xE78A0E8319Ef75B3e381026F93A84330656DDEE8;

        (silo0, silo1) = ISiloConfig(siloConfig).getSilos();

        token0 = ISiloConfig(siloConfig).getAssetForSilo(silo0);
        token1 = ISiloConfig(siloConfig).getAssetForSilo(silo1);

        (protectedToken0, collateralToken0, debtToken0) = ISiloConfig(siloConfig).getShareTokens(silo0);
        (protectedToken1, collateralToken1, debtToken1) = ISiloConfig(siloConfig).getShareTokens(silo1);

        vm.prank(wethWhale);
        IERC20(token0).transfer(depositor, _TOKEN0_AMOUNT);

        vm.prank(usdcWhale);
        IERC20(token1).transfer(depositor, _TOKEN1_AMOUNT);

        vm.prank(depositor);
        IERC20(token0).approve(address(router), type(uint256).max);

        vm.prank(depositor);
        IERC20(token1).approve(address(router), type(uint256).max);

        vm.prank(borrower);
        IERC20(token0).approve(address(router), type(uint256).max);

        vm.prank(wethWhale);
        IWrappedNativeToken(token0).withdraw(_ETH_BALANCE);
        
        vm.label(siloConfig, "siloConfig");
        vm.label(silo0, "silo0");
        vm.label(silo1, "silo1");
        vm.label(collateralToken0, "collateralToken0");
        vm.label(protectedToken0, "protectedToken0");
        vm.label(debtToken0, "debtToken0");
        vm.label(collateralToken1, "collateralToken1");
        vm.label(protectedToken1, "protectedToken1");
        vm.label(debtToken1, "debtToken1");
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testDepositViaMulticallRouter
    function testDepositViaMulticallRouter() public {
        uint256 snapshotId = vm.snapshot();

        // actions to be executed via router
        // 1. pull assets to the router
        // 2. approve assets to the silo
        // 3. deposit assets to the silo

        bytes[] memory data = new bytes[](6);
        address[] memory targets = new address[](6);
        uint256[] memory values = new uint256[](6);

        targets[0] = address(IERC20(token0));
        data[0] = abi.encodeWithSelector(
            IERC20.transferFrom.selector,
            depositor,
            address(router),
            _TOKEN0_AMOUNT
        );

        targets[1] = address(IERC20(token0));
        data[1] = abi.encodeWithSelector(
            IERC20.approve.selector,
            address(silo0),
            _TOKEN0_AMOUNT
        );

        targets[2] = address(ISilo(silo0));
        data[2] = abi.encodeWithSelector(
            ISilo.deposit.selector,
            _TOKEN0_AMOUNT,
            depositor,
            ISilo.CollateralType.Collateral
        );

        targets[3] = address(IERC20(token1));
        data[3] = abi.encodeWithSelector(
            IERC20.transferFrom.selector,
            depositor,
            address(router),
            _TOKEN1_AMOUNT
        );

        targets[4] = address(IERC20(token1));
        data[4] = abi.encodeWithSelector(
            IERC20.approve.selector,
            address(silo1),
            _TOKEN1_AMOUNT
        );

        targets[5] = address(ISilo(silo1));
        data[5] = abi.encodeWithSelector(
            ISilo.deposit.selector,
            _TOKEN1_AMOUNT,
            depositor,
            ISilo.CollateralType.Protected
        );

        vm.prank(depositor);
        router.multicall(targets, data, values);

        uint256 collateralBalanceViaRouter = IERC20(collateralToken0).balanceOf(depositor);
        uint256 protectedBalanceViaRouter = IERC20(protectedToken1).balanceOf(depositor);

        assertEq(
            collateralBalanceViaRouter,
            _TOKEN0_AMOUNT.decimalsOffsetPow(),
            "Collateral share token balance mismatch"
        );

        assertEq(
            protectedBalanceViaRouter,
            _TOKEN1_AMOUNT.decimalsOffsetPow(),
            "Protected share token balance mismatch"
        );

        // Reset to the original state to verify results with direct silo deposits.
        vm.revertTo(snapshotId);

        vm.prank(depositor);
        IERC20(token0).approve(silo0, type(uint256).max);

        vm.prank(depositor);
        IERC20(token1).approve(silo1, type(uint256).max);

        vm.prank(depositor);
        ISilo(silo0).deposit(_TOKEN0_AMOUNT, depositor, ISilo.CollateralType.Collateral);

        vm.prank(depositor);
        ISilo(silo1).deposit(_TOKEN1_AMOUNT, depositor, ISilo.CollateralType.Protected);

        uint256 collateralBalanceDirect = IERC20(collateralToken0).balanceOf(depositor);
        uint256 protectedBalanceDirect = IERC20(protectedToken1).balanceOf(depositor);

        assertEq(collateralBalanceViaRouter, collateralBalanceDirect, "Collateral share token balance mismatch");
        assertEq(protectedBalanceViaRouter, protectedBalanceDirect, "Protected share token balance mismatch");
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testMulticallEthTransferFailed
    function testMulticallEthTransferFailed() public {
        assertNotEq(address(this).balance, 0, "Expect to have no balance before");

        bytes[] memory data = new bytes[](1);
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);

        targets[0] = address(IERC20(token0));
        data[0] = abi.encodeWithSelector(
            IERC20.transferFrom.selector,
            depositor,
            address(router),
            _TOKEN0_AMOUNT
        );

        vm.expectRevert(SiloRouter.EthTransferFailed.selector);
        router.multicall{value: address(this).balance}(targets, data, values);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testMulticallWrapNativeTokenOnDeposit
    function testMulticallWrapNativeTokenOnDeposit() public {
        uint256 depositToken0 = address(this).balance;
        assertNotEq(depositToken0, 0, "Expect to have balance before");

        uint256 collateralBalance = IERC20(collateralToken0).balanceOf(address(this));
        assertEq(collateralBalance, 0, "Expect to have no deposits before");

        uint256 token0Balance = IERC20(token0).balanceOf(address(this));
        assertEq(token0Balance, 0, "Expect to have no token0");

        bytes[] memory data = new bytes[](3);
        address[] memory targets = new address[](3);
        uint256[] memory values = new uint256[](3);

        targets[0] = address(IERC20(token0));
        data[0] = abi.encodeWithSelector(IWrappedNativeToken.deposit.selector);
        values[0] = address(this).balance;

        targets[1] = address(IERC20(token0));
        data[1] = abi.encodeWithSelector(
            IERC20.approve.selector,
            address(silo0),
            address(this).balance
        );

        targets[2] = address(ISilo(silo0));
        data[2] = abi.encodeWithSelector(
            ISilo.deposit.selector,
            address(this).balance,
            address(this),
            ISilo.CollateralType.Collateral
        );

        router.multicall{value: address(this).balance}(targets, data, values);

        collateralBalance = IERC20(collateralToken0).balanceOf(address(this));

        assertNotEq(collateralBalance, 0, "Expect to have deposits after");
        assertEq(address(this).balance, 0, "Expect to have 0 balance after");
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testMulticallSendBackEthLeftover
    function testMulticallSendBackEthLeftover() public {
        // transfer eth to the depositor
        payable(depositor).transfer(address(this).balance);

        uint256 depositToken0 = address(depositor).balance;
        assertNotEq(depositToken0, 0, "Expect to have balance before");

        uint256 collateralBalance = IERC20(collateralToken0).balanceOf(address(this));
        assertEq(collateralBalance, 0, "Expect to have no deposits before");

        uint256 token0Balance = IERC20(token0).balanceOf(address(this));
        assertEq(token0Balance, 0, "Expect to have no token0");

        uint256 expectedLeftover = 100;

        bytes[] memory data = new bytes[](3);
        address[] memory targets = new address[](3);
        uint256[] memory values = new uint256[](3);

        targets[0] = address(IERC20(token0));
        data[0] = abi.encodeWithSelector(IWrappedNativeToken.deposit.selector);
        values[0] = depositToken0 - expectedLeftover;

        targets[1] = address(IERC20(token0));
        data[1] = abi.encodeWithSelector(
            IERC20.approve.selector,
            address(silo0),
            type(uint256).max
        );

        targets[2] = address(ISilo(silo0));
        data[2] = abi.encodeWithSelector(
            ISilo.deposit.selector,
            depositToken0 - expectedLeftover,
            address(this),
            ISilo.CollateralType.Collateral
        );

        vm.prank(depositor);
        router.multicall{value: depositToken0}(targets, data, values);

        collateralBalance = IERC20(collateralToken0).balanceOf(address(this));

        assertNotEq(collateralBalance, 0, "Expect to have deposits after");
        assertEq(address(depositor).balance, expectedLeftover, "Expect to have balance after");
    }
}
