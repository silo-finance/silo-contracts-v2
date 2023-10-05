// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloFactory, SiloFactory} from "silo-core/contracts/SiloFactory.sol";

/*
forge test -vv --mc SiloFactorySettersTest
*/
contract SiloFactorySettersTest is Test {
    SiloFactory public siloFactory;

    address siloImpl = address(100001);
    address shareCollateralTokenImpl = address(100002);
    address shareDebtTokenImpl = address(100003);
    uint256 daoFeeInBp = 0.20e4;
    address daoFeeReceiver = address(100004);

    address hacker = address(1000099);

    function setUp() public {
        siloFactory = new SiloFactory();
        siloFactory.initialize(siloImpl, shareCollateralTokenImpl, shareDebtTokenImpl, daoFeeInBp, daoFeeReceiver);
    }

    /*
    forge test -vv --mt test_setDaoFee
    */
    function test_setDaoFee(uint256 _newDaoFee) public {
        uint256 maxFee = siloFactory.MAX_FEE_IN_BP();

        vm.assume(_newDaoFee < maxFee);

        vm.expectRevert(ISiloFactory.MaxFee.selector);
        siloFactory.setDaoFee(maxFee + 1);

        vm.prank(hacker);
        vm.expectRevert("Ownable: caller is not the owner");
        siloFactory.setDaoFee(_newDaoFee);

        siloFactory.setDaoFee(_newDaoFee);

        assertEq(siloFactory.daoFeeInBp(), _newDaoFee);
    }

    /*
    forge test -vv --mt test_setMaxDeployerFee
    */
    function test_setMaxDeployerFee(uint256 _newMaxDeployerFeeInBp) public {
        uint256 maxFee = siloFactory.MAX_FEE_IN_BP();

        vm.assume(_newMaxDeployerFeeInBp < maxFee);

        vm.expectRevert(ISiloFactory.MaxFee.selector);
        siloFactory.setMaxDeployerFee(maxFee + 1);

        vm.prank(hacker);
        vm.expectRevert("Ownable: caller is not the owner");
        siloFactory.setMaxDeployerFee(_newMaxDeployerFeeInBp);

        siloFactory.setMaxDeployerFee(_newMaxDeployerFeeInBp);

        assertEq(siloFactory.maxDeployerFeeInBp(), _newMaxDeployerFeeInBp);
    }

    /*
    forge test -vv --mt test_setMaxFlashloanFee
    */
    function test_setMaxFlashloanFee(uint256 _newMaxFlashloanFeeInBp) public {
        uint256 maxFee = siloFactory.MAX_FEE_IN_BP();

        vm.assume(_newMaxFlashloanFeeInBp < maxFee);

        vm.expectRevert(ISiloFactory.MaxFee.selector);
        siloFactory.setMaxFlashloanFee(maxFee + 1);

        vm.prank(hacker);
        vm.expectRevert("Ownable: caller is not the owner");
        siloFactory.setMaxFlashloanFee(_newMaxFlashloanFeeInBp);

        siloFactory.setMaxFlashloanFee(_newMaxFlashloanFeeInBp);

        assertEq(siloFactory.maxFlashloanFeeInBp(), _newMaxFlashloanFeeInBp);
    }

    /*
    forge test -vv --mt test_setMaxLiquidationFee
    */
    function test_setMaxLiquidationFee(uint256 _newMaxLiquidationFeeInBp) public {
        uint256 maxFee = siloFactory.MAX_FEE_IN_BP();

        vm.assume(_newMaxLiquidationFeeInBp < maxFee);

        vm.expectRevert(ISiloFactory.MaxFee.selector);
        siloFactory.setMaxLiquidationFee(maxFee + 1);

        vm.prank(hacker);
        vm.expectRevert("Ownable: caller is not the owner");
        siloFactory.setMaxLiquidationFee(_newMaxLiquidationFeeInBp);

        siloFactory.setMaxLiquidationFee(_newMaxLiquidationFeeInBp);

        assertEq(siloFactory.maxLiquidationFeeInBp(), _newMaxLiquidationFeeInBp);
    }

    /*
    forge test -vv --mt test_setDaoFeeReceiver
    */
    function test_setDaoFeeReceiver(address _newDaoFeeReceiver) public {
        vm.assume(_newDaoFeeReceiver != address(0));

        vm.expectRevert(ISiloFactory.ZeroAddress.selector);
        siloFactory.setDaoFeeReceiver(address(0));

        vm.prank(hacker);
        vm.expectRevert("Ownable: caller is not the owner");
        siloFactory.setDaoFeeReceiver(_newDaoFeeReceiver);

        siloFactory.setDaoFeeReceiver(_newDaoFeeReceiver);

        assertEq(siloFactory.daoFeeReceiver(), _newDaoFeeReceiver);

        (address dao, address deployer) = siloFactory.getFeeReceivers(address(1));

        assertEq(dao, _newDaoFeeReceiver);
        assertEq(deployer, address(0));
    }
}
