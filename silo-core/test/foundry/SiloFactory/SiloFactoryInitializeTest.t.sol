// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {ISiloFactory, SiloFactory, Ownable} from "silo-core/contracts/SiloFactory.sol";
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
    forge test -vv --mt test_initialize_onlyOwner
    */
    function test_initialize_onlyOwner() public {
        SiloFactory f = new SiloFactory();

        address siloImpl = address(1);
        address shareProtectedCollateralTokenImpl = address(1);
        address shareDebtTokenImpl = address(1);
        uint256 daoFee;
        address daoFeeReceiver = address(1);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, daoFeeReceiver));
        vm.prank(daoFeeReceiver);
        f.initialize(siloImpl, shareProtectedCollateralTokenImpl, shareDebtTokenImpl, daoFee, daoFeeReceiver);

        f.initialize(siloImpl, shareProtectedCollateralTokenImpl, shareDebtTokenImpl, daoFee, daoFeeReceiver);
    }

    /*
    forge test -vv --mt test_initialize_invalidInitialization
    */
    function test_initialize_invalidInitialization(
        address _siloImpl,
        address _shareProtectedCollateralTokenImpl,
        address _shareDebtTokenImpl,
        uint256 _daoFee,
        address _daoFeeReceiver
    ) public {
        _assumeInitializeParams(
            _siloImpl,
            _shareProtectedCollateralTokenImpl,
            _shareDebtTokenImpl,
            _daoFee,
            _daoFeeReceiver
        );

        siloFactory.initialize(
            _siloImpl, _shareProtectedCollateralTokenImpl, _shareDebtTokenImpl, _daoFee, _daoFeeReceiver
        );

        vm.expectRevert(ISiloFactory.InvalidInitialization.selector);
        siloFactory.initialize(
            _siloImpl, _shareProtectedCollateralTokenImpl, _shareDebtTokenImpl, _daoFee, _daoFeeReceiver
        );
    }

    /*
    forge test -vv --mt test_initialize_zeroAddress
    */
    function test_initialize_zeroAddress(
        address _siloImpl,
        address _shareProtectedCollateralTokenImpl,
        address _shareDebtTokenImpl,
        uint256 _daoFee,
        address _daoFeeReceiver
    ) public {
        _assumeInitializeParams(
            _siloImpl,
            _shareProtectedCollateralTokenImpl,
            _shareDebtTokenImpl,
            _daoFee,
            _daoFeeReceiver
        );

        vm.expectRevert(ISiloFactory.ZeroAddress.selector);
        siloFactory.initialize(
            address(0), _shareProtectedCollateralTokenImpl, _shareDebtTokenImpl, _daoFee, _daoFeeReceiver
        );

        vm.expectRevert(ISiloFactory.ZeroAddress.selector);
        siloFactory.initialize(_siloImpl, address(0), _shareDebtTokenImpl, _daoFee, _daoFeeReceiver);

        vm.expectRevert(ISiloFactory.ZeroAddress.selector);
        siloFactory.initialize(_siloImpl, _shareProtectedCollateralTokenImpl, address(0), _daoFee, _daoFeeReceiver);

        vm.expectRevert(ISiloFactory.ZeroAddress.selector);
        siloFactory.initialize(
            _siloImpl, _shareProtectedCollateralTokenImpl, _shareDebtTokenImpl, _daoFee, address(0)
        );
    }

    /*
    forge test -vv --mt test_initialize_maxFeeExceeded
    */
    function test_initialize_maxFeeExceeded(
        address _siloImpl,
        address _shareProtectedCollateralTokenImpl,
        address _shareDebtTokenImpl,
        uint256 _daoFee,
        address _daoFeeReceiver
    ) public {
        _assumeInitializeParams(
            _siloImpl,
            _shareProtectedCollateralTokenImpl,
            _shareDebtTokenImpl,
            _daoFee,
            _daoFeeReceiver
        );

        uint256 maxFee = siloFactory.MAX_FEE();

        vm.expectRevert(ISiloFactory.MaxFeeExceeded.selector);
        siloFactory.initialize(
            _siloImpl, _shareProtectedCollateralTokenImpl, _shareDebtTokenImpl, maxFee + 1, _daoFeeReceiver
        );
    }

    /*
    forge test -vv --mt test_initialize
    */
    function test_initialize(
        address _siloImpl,
        address _shareProtectedCollateralTokenImpl,
        address _shareDebtTokenImpl,
        uint256 _daoFee,
        address _daoFeeReceiver
    ) public {
        _assumeInitializeParams(
            _siloImpl,
            _shareProtectedCollateralTokenImpl,
            _shareDebtTokenImpl,
            _daoFee,
            _daoFeeReceiver
        );

        siloFactory.initialize(
            _siloImpl, _shareProtectedCollateralTokenImpl, _shareDebtTokenImpl, _daoFee, _daoFeeReceiver
        );

        assertEq(siloFactory.MAX_FEE(), 0.4e18);
        assertEq(siloFactory.MAX_PERCENT(), 1e18);
        assertEq(siloFactory.name(), "Silo Finance Fee Receiver");
        assertEq(siloFactory.symbol(), "feeSILO");
        assertEq(siloFactory.owner(), address(this));
        assertEq(siloFactory.getNextSiloId(), 1);
        assertEq(siloFactory.siloImpl(), _siloImpl);
        assertEq(siloFactory.shareProtectedCollateralTokenImpl(), _shareProtectedCollateralTokenImpl);
        assertEq(siloFactory.shareDebtTokenImpl(), _shareDebtTokenImpl);
        assertEq(siloFactory.daoFee(), _daoFee);
        assertEq(siloFactory.daoFeeReceiver(), _daoFeeReceiver);
        assertEq(siloFactory.maxDeployerFee(), 0.15e18);
        assertEq(siloFactory.maxFlashloanFee(), 0.15e18);
        assertEq(siloFactory.maxLiquidationFee(), 0.3e18);

        assertTrue(_test_transfer2StepOwnership(address(siloFactory), address(this)));
    }

    function _assumeInitializeParams(
        address _siloImpl,
        address _shareProtectedCollateralTokenImpl,
        address _shareDebtTokenImpl,
        uint256 _daoFee,
        address _daoFeeReceiver
    ) internal view {
        vm.assume(_siloImpl != address(0));
        vm.assume(_shareProtectedCollateralTokenImpl != address(0));
        vm.assume(_shareDebtTokenImpl != address(0));
        vm.assume(_daoFeeReceiver != address(0));

        uint256 maxFee = siloFactory.MAX_FEE();

        vm.assume(_daoFee < maxFee);
    }
}
