// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloFactory, SiloFactory} from "silo-core/contracts/SiloFactory.sol";

/*
forge test -vv --mc SiloFactoryInitializeTest
*/
contract SiloFactoryInitializeTest is Test {
    SiloFactory public siloFactory;

    function setUp() public {
        siloFactory = new SiloFactory();
    }

    /*
    forge test -vv --mt test_initialize
    */
    function test_initialize(
        address _siloImpl,
        address _shareCollateralTokenImpl,
        address _shareDebtTokenImpl,
        uint256 _daoFeeInBp,
        address _daoFeeReceiver
    ) public {
        vm.assume(_siloImpl != address(0));
        vm.assume(_shareCollateralTokenImpl != address(0));
        vm.assume(_shareDebtTokenImpl != address(0));
        vm.assume(_daoFeeReceiver != address(0));

        uint256 maxFee = siloFactory.MAX_FEE_IN_BP();

        vm.assume(_daoFeeInBp < maxFee);

        vm.expectRevert(ISiloFactory.ZeroAddress.selector);
        siloFactory.initialize(
            address(0), _shareCollateralTokenImpl, _shareDebtTokenImpl, _daoFeeInBp, _daoFeeReceiver
        );

        vm.expectRevert(ISiloFactory.ZeroAddress.selector);
        siloFactory.initialize(_siloImpl, address(0), _shareDebtTokenImpl, _daoFeeInBp, _daoFeeReceiver);

        vm.expectRevert(ISiloFactory.ZeroAddress.selector);
        siloFactory.initialize(_siloImpl, _shareCollateralTokenImpl, address(0), _daoFeeInBp, _daoFeeReceiver);

        vm.expectRevert(ISiloFactory.ZeroAddress.selector);
        siloFactory.initialize(_siloImpl, _shareCollateralTokenImpl, _shareDebtTokenImpl, _daoFeeInBp, address(0));

        vm.expectRevert(ISiloFactory.MaxFee.selector);
        siloFactory.initialize(_siloImpl, _shareCollateralTokenImpl, _shareDebtTokenImpl, maxFee + 1, _daoFeeReceiver);

        siloFactory.initialize(_siloImpl, _shareCollateralTokenImpl, _shareDebtTokenImpl, _daoFeeInBp, _daoFeeReceiver);

        assertEq(siloFactory.name(), "Silo Finance Fee Receiver");
        assertEq(siloFactory.symbol(), "feeSILO");
        assertEq(siloFactory.owner(), address(this));
        assertEq(siloFactory.getNextSiloId(), 1);
        assertEq(siloFactory.siloImpl(), _siloImpl);
        assertEq(siloFactory.shareCollateralTokenImpl(), _shareCollateralTokenImpl);
        assertEq(siloFactory.shareDebtTokenImpl(), _shareDebtTokenImpl);
        assertEq(siloFactory.daoFeeInBp(), _daoFeeInBp);
        assertEq(siloFactory.maxDeployerFeeInBp(), 0.15e4);
        assertEq(siloFactory.maxFlashloanFeeInBp(), 0.15e4);
        assertEq(siloFactory.maxLiquidationFeeInBp(), 0.3e4);
    }
}
