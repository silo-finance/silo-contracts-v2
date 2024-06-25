// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {SiloERC4626} from "silo-core/contracts/utils/SiloERC4626.sol";
import {IMethodReentrancyTest} from "../interfaces/IMethodReentrancyTest.sol";
import {TestStateLib} from "../TestState.sol";
import {MaliciousToken} from "../MaliciousToken.sol";

contract TransferFromReentrancyTest is Test, IMethodReentrancyTest {
    function callMethod() external {
        MaliciousToken token = MaliciousToken(TestStateLib.token0());
        ISiloConfig config = TestStateLib.siloConfig();
        ISilo silo = TestStateLib.silo0();
        address depositor = makeAddr("Depositor");
        address recepient = makeAddr("Recepient");
        address spender = makeAddr("Spender");
        uint256 amount = 100e18;

        token.mint(depositor, amount);

        vm.prank(depositor);
        token.approve(address(silo), amount);

        vm.prank(depositor);
        silo.deposit(amount, depositor);

        (, address collateralToken,) = config.getShareTokens(address(silo));

        vm.prank(depositor);
        IERC20(collateralToken).approve(spender, amount);

        TestStateLib.enableReentrancy();

        vm.prank(spender);
        SiloERC4626(address(silo)).transferFrom(depositor, recepient, amount);
    }

    function verifyReentrancy() external {
        ISilo silo0 = TestStateLib.silo0();

        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        SiloERC4626(address(silo0)).transferFrom(address(0), address(0), 1000);

        ISilo silo1 = TestStateLib.silo1();

        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        SiloERC4626(address(silo1)).transferFrom(address(0), address(0), 1000);
    }

    function methodDescription() external pure returns (string memory description) {
        description = "transferFrom(address,address,uint256)";
    }

    function methodSignature() external pure returns (bytes4 sig) {
        sig = SiloERC4626.transferFrom.selector;
    }
}
