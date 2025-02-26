// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {IWrappedNativeToken} from "silo-core/contracts/interfaces/IWrappedNativeToken.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

interface IEggs {
    function buy(address receiver) external payable;
    function sell(uint256 eggs) external;
    function borrow(uint256 sonic, uint256 numberOfDays) external;
    function SONICtoEGGS(uint256 value) external view returns (uint256);
    function EGGStoSONIC(uint256 value) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

// FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc EggsSonicPriceProvider
contract EggsSonicPriceProvider is IntegrationTest {
    IEggs internal _eggs = IEggs(0xf26Ff70573ddc8a90Bd7865AF8d7d70B8Ff019bC);
    address internal _eggsWhale = 0x66A8289bdD968D1157eB1a608f60a87759632cd6;

    function setUp() public {
        uint256 blockToFork = 10053279;
        vm.createSelectFork(vm.envString("RPC_SONIC"), blockToFork);
    }

    receive() external payable {}

    /*
    FOUNDRY_PROFILE=core-test forge test -vv --ffi --mt test_priceManipulation_sell

    Whale balance 	1,593,795,176
    */
    function test_priceManipulation_sell() public {
        uint256 priceBefore = _eggs.EGGStoSONIC(1e18);
        assertEq(priceBefore, 1136010235775762, "priceBefore");

        uint256 eggsAmount = _eggs.balanceOf(address(_eggsWhale));

        vm.prank(_eggsWhale);
        IERC20(address(_eggs)).transfer(address(this), eggsAmount);

        _eggs.sell(eggsAmount);

        uint256 priceAfter = _eggs.EGGStoSONIC(1e18);
        assertEq(priceAfter, 1136374922743370, "priceAfter");

        assertGt(priceAfter, priceBefore, "Price should have increased");
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vv --ffi --mt test_priceManipulation_borrow
    */
    function test_priceManipulation_borrow() public {
        uint256 priceBefore = _eggs.EGGStoSONIC(1e18);
        assertEq(priceBefore, 1136010235775762, "priceBefore");

        uint256 sonicAmount = 1000_000e18;
        uint256 eggsAmount = _eggs.balanceOf(address(_eggsWhale));

        vm.prank(_eggsWhale);
        IERC20(address(_eggs)).transfer(address(this), eggsAmount);

        _eggs.borrow(sonicAmount, 1);

        uint256 priceAfter = _eggs.EGGStoSONIC(1e18);
        assertEq(priceAfter, 1136019114778502, "priceAfter");

        assertGt(priceAfter, priceBefore, "Price should have increased");
    }
}
