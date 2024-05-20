// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {ISiloFactory, SiloFactory, Creator} from "silo-core/contracts/SiloFactory.sol";
import {TransferOwnership} from "../_common/TransferOwnership.sol";

/*
forge test -vv --mc SiloFactoryInitializeTest
*/
contract SiloFactoryInitializeTest is Test, TransferOwnership {
    SiloFactory public siloFactory;

    function setUp() public {
        siloFactory = new SiloFactory();
    }

    /*
    forge test -vv --mt test_initialize_onlyCreator
    */
    function test_initialize_onlyCreator() public {
        SiloFactory f = new SiloFactory();

        address siloImpl = address(1);
        address shareCollateralTokenImpl = address(1);
        address shareDebtTokenImpl = address(1);
        uint256 daoFee;
        address daoFeeReceiver = address(1);

        vm.expectRevert(Creator.OnlyCreator.selector);
        vm.prank(address(1));
        f.initialize(siloImpl, shareCollateralTokenImpl, shareDebtTokenImpl, daoFee, daoFeeReceiver);

        f.initialize(siloImpl, shareCollateralTokenImpl, shareDebtTokenImpl, daoFee, daoFeeReceiver);
    }

    /*
    forge test -vv --mt test_initialize
    */
    function test_initialize(
        address _siloImpl,
        address _shareCollateralTokenImpl,
        address _shareDebtTokenImpl,
        uint256 _daoFee,
        address _daoFeeReceiver
    ) public {
        vm.assume(_siloImpl != address(0));
        vm.assume(_shareCollateralTokenImpl != address(0));
        vm.assume(_shareDebtTokenImpl != address(0));
        vm.assume(_daoFeeReceiver != address(0));

        uint256 maxFee = siloFactory.MAX_FEE();

        vm.assume(_daoFee < maxFee);

        vm.expectRevert(ISiloFactory.ZeroAddress.selector);
        siloFactory.initialize(
            address(0), _shareCollateralTokenImpl, _shareDebtTokenImpl, _daoFee, _daoFeeReceiver
        );

        vm.expectRevert(ISiloFactory.ZeroAddress.selector);
        siloFactory.initialize(_siloImpl, address(0), _shareDebtTokenImpl, _daoFee, _daoFeeReceiver);

        vm.expectRevert(ISiloFactory.ZeroAddress.selector);
        siloFactory.initialize(_siloImpl, _shareCollateralTokenImpl, address(0), _daoFee, _daoFeeReceiver);

        vm.expectRevert(ISiloFactory.ZeroAddress.selector);
        siloFactory.initialize(_siloImpl, _shareCollateralTokenImpl, _shareDebtTokenImpl, _daoFee, address(0));

        vm.expectRevert(ISiloFactory.MaxFee.selector);
        siloFactory.initialize(_siloImpl, _shareCollateralTokenImpl, _shareDebtTokenImpl, maxFee + 1, _daoFeeReceiver);

        siloFactory.initialize(_siloImpl, _shareCollateralTokenImpl, _shareDebtTokenImpl, _daoFee, _daoFeeReceiver);

        assertEq(siloFactory.name(), "Silo Finance Fee Receiver");
        assertEq(siloFactory.symbol(), "feeSILO");
        assertEq(siloFactory.owner(), address(this));
        assertEq(siloFactory.getNextSiloId(), 1);
        assertEq(siloFactory.siloImpl(), _siloImpl);
        assertEq(siloFactory.shareCollateralTokenImpl(), _shareCollateralTokenImpl);
        assertEq(siloFactory.shareDebtTokenImpl(), _shareDebtTokenImpl);
        assertEq(siloFactory.daoFee(), _daoFee);
        assertEq(siloFactory.maxDeployerFee(), 0.15e18);
        assertEq(siloFactory.maxFlashloanFee(), 0.15e18);
        assertEq(siloFactory.maxLiquidationFee(), 0.3e18);

        assertTrue(_test_transfer2StepOwnership(address(siloFactory), address(this)));
    }
}
