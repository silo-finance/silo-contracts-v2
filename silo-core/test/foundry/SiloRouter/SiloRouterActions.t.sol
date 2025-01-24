// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";

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

    uint256 internal constant _FORKING_BLOCK_NUMBER = 5222185;
    uint256 internal constant _S_BALANCE = 10e18;
    uint256 internal constant _TOKEN0_AMOUNT = 100e18;
    uint256 internal constant _TOKEN1_AMOUNT = 100e6;

    address public silo0;
    address public silo1;
    address public token0; // S
    address public token1; // USDC

    address public depositor = makeAddr("Depositor");
    address public borrower = makeAddr("Borrower");

    IWrappedNativeToken public nativeToken = IWrappedNativeToken(0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38);

    address public wsWhale = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address public usdcWhale = 0xb3FC32de77d62A35621e48DDf1Aac8C24Be215a6;

    address public collateralToken0;
    address public protectedToken0;
    address public debtToken0;

    address public collateralToken1;
    address public protectedToken1;
    address public debtToken1;

    SiloRouter public router;
    address public routerOwner;

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_SONIC"), _FORKING_BLOCK_NUMBER);

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        routerOwner = vm.addr(deployerPrivateKey);

        SiloRouterDeploy deploy = new SiloRouterDeploy();
        deploy.disableDeploymentsSync();

        router = deploy.run();

        address siloConfig = 0x4915F6d3C9a7B20CedFc5d3854f2802f30311d13; // S/USDC

        (silo0, silo1) = ISiloConfig(siloConfig).getSilos();

        token0 = ISiloConfig(siloConfig).getAssetForSilo(silo0);
        token1 = ISiloConfig(siloConfig).getAssetForSilo(silo1);

        (protectedToken0, collateralToken0, debtToken0) = ISiloConfig(siloConfig).getShareTokens(silo0);
        (protectedToken1, collateralToken1, debtToken1) = ISiloConfig(siloConfig).getShareTokens(silo1);

        vm.prank(wsWhale);
        IERC20(token0).transfer(depositor, _TOKEN0_AMOUNT);

        vm.prank(usdcWhale);
        IERC20(token1).transfer(depositor, _TOKEN1_AMOUNT);

        vm.prank(depositor);
        IERC20(token0).approve(address(router), type(uint256).max);

        vm.prank(depositor);
        IERC20(token1).approve(address(router), type(uint256).max);

        vm.prank(borrower);
        IERC20(token0).approve(address(router), type(uint256).max);

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

    // FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_siloRouter_pause_unpause
    function test_siloRouter_pause_unpause() public {
        assertFalse(router.paused(), "Router should not be paused");

        vm.expectRevert(abi.encodeWithSelector(
            Ownable.OwnableUnauthorizedAccount.selector,
            address(this)
        ));

        router.pause();

        vm.prank(routerOwner);
        router.pause();
        assertTrue(router.paused(), "Router should be paused");

        vm.expectRevert(abi.encodeWithSelector(
            Ownable.OwnableUnauthorizedAccount.selector,
            address(this)
        ));

        router.unpause();

        vm.prank(routerOwner);
        router.unpause();
        assertFalse(router.paused(), "Router should not be paused");
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_siloRouter_wrapAndTransfer_nativeToken
    function test_siloRouter_wrapAndTransfer_nativeToken() public {
        address receiver = makeAddr("Receiver");

        vm.prank(wsWhale);
        nativeToken.withdraw(_S_BALANCE);

        assertEq(nativeToken.balanceOf(receiver), 0, "Receiver should not have any native tokens");

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(router.wrap.selector, IWrappedNativeToken(nativeToken), _S_BALANCE);
        data[1] = abi.encodeWithSelector(router.transfer.selector, nativeToken, receiver, _S_BALANCE);

        vm.prank(wsWhale);
        router.multicall{value: _S_BALANCE}(data);

        assertEq(nativeToken.balanceOf(receiver), _S_BALANCE, "Receiver should have native tokens");
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_siloRouter_unwrapAndTransfer_nativeToken
    function test_siloRouter_unwrapAndTransfer_nativeToken() public {
        assertEq(wsWhale.balance, 0, "Account should not have any native tokens");

        vm.prank(wsWhale);
        IERC20(nativeToken).approve(address(router), _S_BALANCE);

        address receiver = makeAddr("Receiver");

        bytes[] memory data = new bytes[](3);

        data[0] = abi.encodeWithSelector(
            router.transferFrom.selector,
            IWrappedNativeToken(nativeToken),
            address(router),
            _S_BALANCE
        );

        data[1] = abi.encodeWithSelector(router.unwrap.selector, IWrappedNativeToken(nativeToken), _S_BALANCE);
        data[2] = abi.encodeWithSelector(router.transferNative.selector, receiver, _S_BALANCE);

        vm.prank(wsWhale);
        router.multicall(data);

        assertEq(receiver.balance, _S_BALANCE, "Account should have native tokens");
    }
}
