// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {DexSwap} from "silo-core/contracts/utils/liquidationHelper/DexSwap.sol";

/*
 forge test --gas-price 1 -vv --mc DexSwapOdosSonicTest
*/
contract DexSwapOdosSonicTest is Test {
    DexSwap dex; // solhint-disable-line var-name-mixedcase

    address public constant ODOS_ROUTER = address(0xaC041Df48dF9791B0654f1Dbbf2CC8450C5f2e9D);

    function setUp() public {
        uint256 blockToFork = 2838462;
        vm.createSelectFork(vm.envString("RPC_SONIC"), blockToFork);

        dex = new DexSwap(ODOS_ROUTER);
    }

    function test_fillQuote_StoWETH() public {
        address whale = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

        IERC20 sellToken = IERC20(0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38); // wS
        vm.prank(whale);
        sellToken.transfer(address(dex),50e18);

        IERC20 buyToken = IERC20(0x50c42dEAcD8Fc9773493ED674b675bE577f2634b);
        address allowanceTarget = ODOS_ROUTER;

        uint256 wethBefore = buyToken.balanceOf(address(dex));
        assertEq(wethBefore, 0, "expect to have no WETH");

        // seller address in swap data: 5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
        bytes memory swapCallData = hex"83bd37f90001039e2fb66102314ce7b64ce5ce3e5183bc94ad38000150c42deacd8fc9773493ed674b675be577f2634b0902b5e3af16b188000007257ed11a78e51e028f5c00018e7591e2919157A6BBE9E3defe0F1Ff793e65Ec1000000015615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f000000000301020300060101010201ff000000000000000000000000000000000000000000e45a270b10cfed62ba586d3f1b72b36989a623ba039e2fb66102314ce7b64ce5ce3e5183bc94ad38000000000000000000000000000000000000000000000000";
        dex.fillQuote(address(sellToken), allowanceTarget, swapCallData);

        assertEq(buyToken.balanceOf(address(dex)), 10535913188180254, "expect to have WETH");
        assertEq(sellToken.allowance(address(dex), allowanceTarget), 0, "allowance should be reset to 0");
    }
}
