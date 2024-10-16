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

// solhint-disable function-max-lines

// FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc SiloRouterActionsTest
contract SiloRouterActionsTest is IntegrationTest {
    uint256 internal constant _FORKING_BLOCK_NUMBER = 253050446;
    uint256 internal constant _ETH_BALANCE = 10e18;

    address public silo0;
    address public silo1;
    address public token0; // weth
    address public token1; // usdc

    address public depositor = makeAddr("Depositor");
    address public borrower = makeAddr("Borrower");

    address wethWhale = 0x70d95587d40A2caf56bd97485aB3Eec10Bee6336;
    address usdcWhale = 0xa0E9B6DA89BD0303A8163B81B8702388bE0Fde77;

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

        address siloConfig = SiloDeployments.get(
            ARBITRUM_ONE_ALIAS,
            SiloConfigsNames.ETH_USDC_UNI_V3_SILO
        );

        (silo0, silo1) = ISiloConfig(siloConfig).getSilos();

        token0 = ISiloConfig(siloConfig).getAssetForSilo(silo0);
        token1 = ISiloConfig(siloConfig).getAssetForSilo(silo1);

        (protectedToken0, collateralToken0, debtToken0) = ISiloConfig(siloConfig).getShareTokens(silo0);
        (protectedToken1, collateralToken1, debtToken1) = ISiloConfig(siloConfig).getShareTokens(silo1);

        vm.prank(wethWhale);
        IERC20(token0).transfer(depositor, 1000e18);

        vm.prank(usdcWhale);
        IERC20(token1).transfer(depositor, 1000e6);

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

    // FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testDepositViaRouter
    function testDepositViaRouter() public {
        uint256 snapshotId = vm.snapshot();

        uint256 depositToken0 = 100e18;
        uint256 depositToken1 = 100e6;

        SiloRouter.AnyAction memory options0 = SiloRouter.AnyAction({
            amount: depositToken0,
            assetType: ISilo.CollateralType.Collateral
        });

        SiloRouter.Action memory action0 = SiloRouter.Action({
            actionType: SiloRouter.ActionType.Deposit,
            silo: ISilo(silo0),
            asset: IERC20(token0),
            options: abi.encode(options0)
        });

        SiloRouter.AnyAction memory options1 = SiloRouter.AnyAction({
            amount: depositToken1,
            assetType: ISilo.CollateralType.Protected
        });

        SiloRouter.Action memory action1 = SiloRouter.Action({
            actionType: SiloRouter.ActionType.Deposit,
            silo: ISilo(silo1),
            asset: IERC20(token1),
            options: abi.encode(options1)
        });

        SiloRouter.Action[] memory actions = new SiloRouter.Action[](2);
        actions[0] = action0;
        actions[1] = action1;

        vm.prank(depositor);
        router.execute(actions);

        uint256 collateralBalanceViaRouter = IERC20(collateralToken0).balanceOf(depositor);
        uint256 protectedBalanceViaRouter = IERC20(protectedToken1).balanceOf(depositor);

        assertEq(collateralBalanceViaRouter, depositToken0, "Collateral share token balance mismatch");
        assertEq(protectedBalanceViaRouter, depositToken1, "Protected share token balance mismatch");

        // Reset to the original state to verify results with direct silo deposits.
        vm.revertTo(snapshotId);

        vm.prank(depositor);
        IERC20(token0).approve(silo0, type(uint256).max);

        vm.prank(depositor);
        IERC20(token1).approve(silo1, type(uint256).max);

        vm.prank(depositor);
        ISilo(silo0).deposit(depositToken0, depositor, ISilo.CollateralType.Collateral);

        vm.prank(depositor);
        ISilo(silo1).deposit(depositToken1, depositor, ISilo.CollateralType.Protected);

        uint256 collateralBalanceDirect = IERC20(collateralToken0).balanceOf(depositor);
        uint256 protectedBalanceDirect = IERC20(protectedToken1).balanceOf(depositor);

        assertEq(collateralBalanceViaRouter, collateralBalanceDirect, "Collateral share token balance mismatch");
        assertEq(protectedBalanceViaRouter, protectedBalanceDirect, "Protected share token balance mismatch");
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testMintViaRouter
    function testMintViaRouter() public {
        uint256 snapshotId = vm.snapshot();

        uint256 depositToken0 = 100e18;
        uint256 depositToken1 = 100e6;

        SiloRouter.AnyAction memory options0 = SiloRouter.AnyAction({
            amount: depositToken0,
            assetType: ISilo.CollateralType.Collateral
        });

        SiloRouter.Action memory action0 = SiloRouter.Action({
            actionType: SiloRouter.ActionType.Mint,
            silo: ISilo(silo0),
            asset: IERC20(token0),
            options: abi.encode(options0)
        });

        SiloRouter.AnyAction memory options1 = SiloRouter.AnyAction({
            amount: depositToken1,
            assetType: ISilo.CollateralType.Protected
        });

        SiloRouter.Action memory action1 = SiloRouter.Action({
            actionType: SiloRouter.ActionType.Mint,
            silo: ISilo(silo1),
            asset: IERC20(token1),
            options: abi.encode(options1)
        });

        SiloRouter.Action[] memory actions = new SiloRouter.Action[](2);
        actions[0] = action0;
        actions[1] = action1;

        vm.prank(depositor);
        router.execute(actions);

        uint256 collateralBalanceViaRouter = IERC20(collateralToken0).balanceOf(depositor);
        uint256 protectedBalanceViaRouter = IERC20(protectedToken1).balanceOf(depositor);

        assertEq(collateralBalanceViaRouter, depositToken0, "Collateral share token balance mismatch");
        assertEq(protectedBalanceViaRouter, depositToken1, "Protected share token balance mismatch");

        // Reset to the original state to verify results with direct silo deposits.
        vm.revertTo(snapshotId);

        vm.prank(depositor);
        IERC20(token0).approve(silo0, type(uint256).max);

        vm.prank(depositor);
        IERC20(token1).approve(silo1, type(uint256).max);

        vm.prank(depositor);
        ISilo(silo0).mint(depositToken0, depositor, ISilo.CollateralType.Collateral);

        vm.prank(depositor);
        ISilo(silo1).mint(depositToken1, depositor, ISilo.CollateralType.Protected);

        uint256 collateralBalanceDirect = IERC20(collateralToken0).balanceOf(depositor);
        uint256 protectedBalanceDirect = IERC20(protectedToken1).balanceOf(depositor);

        assertEq(collateralBalanceViaRouter, collateralBalanceDirect, "Collateral share token balance mismatch");
        assertEq(protectedBalanceViaRouter, protectedBalanceDirect, "Protected share token balance mismatch");
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testRepayViaRouter
    function testRepayViaRouter() public {
        _borrow();

        uint256 debtShares = IERC20(debtToken0).balanceOf(borrower);
        assertNotEq(debtShares, 0, "Expect to have debt shares");

        uint256 snapshotId = vm.snapshot();

        SiloRouter.AnyAction memory options = SiloRouter.AnyAction({
            amount: debtShares,
            assetType: ISilo.CollateralType.Collateral // doesn't matter
        });

        SiloRouter.Action memory actionRepay = SiloRouter.Action({
            actionType: SiloRouter.ActionType.Repay,
            silo: ISilo(silo0),
            asset: IERC20(token0),
            options: abi.encode(options)
        });

        SiloRouter.Action[] memory actions = new SiloRouter.Action[](1);
        actions[0] = actionRepay;

        vm.prank(borrower);
        router.execute(actions);

        uint256 debtSharesAfterRepay = IERC20(debtToken0).balanceOf(borrower);

        assertEq(debtSharesAfterRepay, 0, "Debt repay failed");

        vm.revertTo(snapshotId);

        debtShares = IERC20(debtToken0).balanceOf(borrower);
        assertNotEq(debtShares, 0, "Expect to have debt shares");

        SiloRouter.Action memory actionRepayShares = SiloRouter.Action({
            actionType: SiloRouter.ActionType.RepayShares,
            silo: ISilo(silo0),
            asset: IERC20(token0),
            options: abi.encode(options)
        });

        actions[0] = actionRepayShares;

        vm.prank(borrower);
        router.execute(actions);

        uint256 debtSharesAfterRepayShares = IERC20(debtToken0).balanceOf(borrower);

        assertEq(debtSharesAfterRepayShares, 0, "Debt repayShares failed");
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testSendAssetsBackFromTheRouter
    function testSendAssetsBackFromTheRouter() public {
        uint256 depositToken0 = 100e18;
        uint256 depositToken1 = 100e6;

        SiloRouter.AnyAction memory options0 = SiloRouter.AnyAction({
            amount: depositToken0,
            assetType: ISilo.CollateralType.Collateral
        });

        SiloRouter.Action memory action0 = SiloRouter.Action({
            actionType: SiloRouter.ActionType.Deposit,
            silo: ISilo(silo0),
            asset: IERC20(token0),
            options: abi.encode(options0)
        });

        SiloRouter.AnyAction memory options1 = SiloRouter.AnyAction({
            amount: depositToken1,
            assetType: ISilo.CollateralType.Protected
        });

        SiloRouter.Action memory action1 = SiloRouter.Action({
            actionType: SiloRouter.ActionType.Deposit,
            silo: ISilo(silo1),
            asset: IERC20(token1),
            options: abi.encode(options1)
        });

        SiloRouter.Action[] memory actions = new SiloRouter.Action[](2);
        actions[0] = action0;
        actions[1] = action1;

        assertEq(IERC20(token0).balanceOf(address(router)), 0, "Expect to have 0 balance");
        assertEq(IERC20(token1).balanceOf(address(router)), 0, "Expect to have 0 balance");

        uint256 routerToken0Balance = 1000e18;
        uint256 routerToken1Balance = 1000e6;

        // send assets to the router (only for the test purposes)
        vm.prank(wethWhale);
        IERC20(token0).transfer(address(router), routerToken0Balance);

        vm.prank(usdcWhale);
        IERC20(token1).transfer(address(router), routerToken1Balance);

        assertEq(IERC20(token0).balanceOf(address(router)), routerToken0Balance, "Expect to have balance");
        assertEq(IERC20(token1).balanceOf(address(router)), routerToken1Balance, "Expect to have balance");

        uint256 depositorBalanceBeforeToken0 = IERC20(token0).balanceOf(depositor);
        uint256 depositorBalanceBeforeToken1 = IERC20(token1).balanceOf(depositor);

        vm.prank(depositor);
        router.execute(actions);

        uint256 depositorBalanceAfterToken0 = IERC20(token0).balanceOf(depositor);
        uint256 depositorBalanceAfterToken1 = IERC20(token1).balanceOf(depositor);

        uint256 depositorExpectedBalanceToken1 = depositorBalanceBeforeToken1 - depositToken1 + routerToken1Balance;

        assertEq(depositorBalanceAfterToken0, depositorBalanceBeforeToken0, "Depositor balance mismatch");
        assertEq(depositorBalanceAfterToken1, depositorExpectedBalanceToken1, "Depositor balance mismatch");
        assertEq(address(depositor).balance, routerToken0Balance - depositToken0, "Depositor balance mismatch");
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testSendAssetsFailedTransfer
    function testSendAssetsFailedTransfer() public {
        uint256 depositToken0 = 100e18;

        SiloRouter.AnyAction memory options0 = SiloRouter.AnyAction({
            amount: depositToken0,
            assetType: ISilo.CollateralType.Collateral
        });

        SiloRouter.Action memory action0 = SiloRouter.Action({
            actionType: SiloRouter.ActionType.Deposit,
            silo: ISilo(silo0),
            asset: IERC20(token0),
            options: abi.encode(options0)
        });

        SiloRouter.Action[] memory actions = new SiloRouter.Action[](1);
        actions[0] = action0;

        assertEq(IERC20(token0).balanceOf(address(router)), 0, "Expect to have 0 balance");

        uint256 routerToken0Balance = 1000e18;

        // send assets to the router (only for the test purposes)
        vm.prank(wethWhale);
        IERC20(token0).transfer(address(router), routerToken0Balance);

        assertEq(IERC20(token0).balanceOf(address(router)), routerToken0Balance, "Expect to have balance");

        vm.expectRevert(SiloRouter.ERC20TransferFailed.selector);
        router.execute(actions);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testEthTransferFailed
    function testEthTransferFailed() public {
        uint256 depositToken1 = 100e6;

        SiloRouter.AnyAction memory options0 = SiloRouter.AnyAction({
            amount: depositToken1,
            assetType: ISilo.CollateralType.Collateral
        });

        SiloRouter.Action memory action0 = SiloRouter.Action({
            actionType: SiloRouter.ActionType.Deposit,
            silo: ISilo(silo1),
            asset: IERC20(token1),
            options: abi.encode(options0)
        });

        SiloRouter.Action[] memory actions = new SiloRouter.Action[](1);
        actions[0] = action0;

        uint256 balanceBefore = address(this).balance;

        assertNotEq(balanceBefore, 0, "Expect to have balance before");

        vm.prank(usdcWhale);
        IERC20(token1).transfer(address(this), 100e6);

        vm.prank(address(this));
        IERC20(token1).approve(address(router), type(uint256).max);

        vm.expectRevert(SiloRouter.EthTransferFailed.selector);
        router.execute{value: balanceBefore}(actions);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testWrapNativeTokenOnDeposit
    function testWrapNativeTokenOnDeposit() public {
        uint256 depositToken0 = address(this).balance;
        assertNotEq(depositToken0, 0, "Expect to have balance before");

        uint256 collateralBalance = IERC20(collateralToken0).balanceOf(address(this));
        assertEq(collateralBalance, 0, "Expect to have no deposits before");

        uint256 token0Balance = IERC20(token0).balanceOf(address(this));
        assertEq(token0Balance, 0, "Expect to have no token0");

        SiloRouter.AnyAction memory options0 = SiloRouter.AnyAction({
            amount: depositToken0,
            assetType: ISilo.CollateralType.Collateral
        });

        SiloRouter.Action memory action0 = SiloRouter.Action({
            actionType: SiloRouter.ActionType.Deposit,
            silo: ISilo(silo0),
            asset: IERC20(token0),
            options: abi.encode(options0)
        });

        SiloRouter.Action[] memory actions = new SiloRouter.Action[](1);
        actions[0] = action0;

        router.execute{value: depositToken0}(actions);

        collateralBalance = IERC20(collateralToken0).balanceOf(address(this));

        assertNotEq(collateralBalance, 0, "Expect to have deposits after");
        assertEq(address(this).balance, 0, "Expect to have 0 balance after");
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testEthTransferFailed
    function testApproveFailed() public {
        uint256 depositToken1 = 100e6;

        SiloRouter.AnyAction memory options0 = SiloRouter.AnyAction({
            amount: depositToken1,
            assetType: ISilo.CollateralType.Collateral
        });

        SiloRouter.Action memory action0 = SiloRouter.Action({
            actionType: SiloRouter.ActionType.Deposit,
            silo: ISilo(silo1),
            asset: IERC20(token1),
            options: abi.encode(options0)
        });

        SiloRouter.Action[] memory actions = new SiloRouter.Action[](1);
        actions[0] = action0;

        vm.prank(usdcWhale);
        IERC20(token1).transfer(address(this), 100e6);

        vm.prank(address(this));
        IERC20(token1).approve(address(router), type(uint256).max);

        vm.mockCall(
            token1,
            abi.encodeWithSelector(IERC20.approve.selector, address(silo1), type(uint256).max),
            abi.encode(false)
        );

        vm.expectRevert(SiloRouter.ApprovalFailed.selector);
        router.execute(actions);
    }

    function _borrow() internal {
        uint256 depositLiquidity = 100e18;
        uint256 depositCollateral = 100000e6;

        vm.prank(usdcWhale);
        IERC20(token1).transfer(borrower, depositCollateral);

        vm.prank(depositor);
        IERC20(token0).approve(silo0, type(uint256).max);

        vm.prank(borrower);
        IERC20(token1).approve(silo1, type(uint256).max);

        vm.prank(depositor);
        ISilo(silo0).deposit(depositLiquidity, depositor, ISilo.CollateralType.Collateral);

        vm.prank(borrower);
        ISilo(silo1).deposit(depositCollateral, borrower, ISilo.CollateralType.Protected);

        uint256 borrowAmount = 100e6;

        vm.prank(borrower);
        ISilo(silo0).borrow(borrowAmount, borrower, borrower);
    }
}
