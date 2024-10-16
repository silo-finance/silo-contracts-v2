// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {SiloLittleHelper} from "silo-core/test/foundry/_common/SiloLittleHelper.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";

/*
    forge test -vv --ffi --mc SiloLensTest
*/
contract SiloLensTest is SiloLittleHelper, Test {
    uint256 constant internal _AMOUNT_COLLATERAL = 1000e18;
    uint256 constant internal _AMOUNT_PROTECTED = 1000e18;
    uint256 constant internal _AMOUNT_BORROW = 500e18;

    address internal _depositor = makeAddr("Depositor");
    address internal _borrower = makeAddr("Borrower");

    ISiloConfig internal _siloConfig;

    function setUp() public {
        _siloConfig = _setUpLocalFixture();

        _makeDeposit(
            silo1, token1, _AMOUNT_COLLATERAL, _depositor, ISilo.CollateralType.Collateral
        );

        _makeDeposit(
            silo1, token1, _AMOUNT_PROTECTED, _depositor, ISilo.CollateralType.Protected
        );

        _makeDeposit(
            silo0, token0, _AMOUNT_COLLATERAL, _borrower, ISilo.CollateralType.Collateral
        );

        vm.prank(_borrower);
        silo1.borrow(_AMOUNT_BORROW, _borrower, _borrower);
    }

    /*
        forge test -vvv --ffi --mt test_SiloLens_getRawLiquidity
    */
    function test_SiloLens_getRawLiquidity() public view {
        uint256 liquiditySilo0 = siloLens.getRawLiquidity(silo0);
        assertEq(liquiditySilo0, _AMOUNT_COLLATERAL);

        uint256 liquiditySilo1 = siloLens.getRawLiquidity(silo1);
        assertEq(liquiditySilo1, _AMOUNT_COLLATERAL - _AMOUNT_BORROW);
    }

    /*
        forge test -vvv --ffi --mt test_SiloLens_getMaxLtv
    */
    function test_SiloLens_getMaxLtv() public view {
        uint256 maxLtvSilo0 = siloLens.getMaxLtv(silo0);
        assertEq(maxLtvSilo0, _siloConfig.getConfig(address(silo0)).maxLtv);

        uint256 maxLtvSilo1 = siloLens.getMaxLtv(silo1);
        assertEq(maxLtvSilo1, _siloConfig.getConfig(address(silo1)).maxLtv);
    }

    /*
        forge test -vvv --ffi --mt test_SiloLens_getLt
    */
    function test_SiloLens_getLt() public view {
        uint256 ltSilo0 = siloLens.getLt(silo0);
        assertEq(ltSilo0, _siloConfig.getConfig(address(silo0)).lt);

        uint256 ltSilo1 = siloLens.getLt(silo1);
        assertEq(ltSilo1, _siloConfig.getConfig(address(silo1)).lt);
    }

    /*
        forge test -vvv --ffi --mt test_SiloLens_getLtv
    */
    function test_SiloLens_getLtv() public view {
        // due to initial state
        uint256 expectedLtv = _AMOUNT_BORROW * 100 / _AMOUNT_COLLATERAL * 1e18 / 100;

        uint256 ltvSilo0 = siloLens.getLtv(silo0, _borrower);
        assertEq(ltvSilo0, expectedLtv);

        uint256 ltvSilo1 = siloLens.getLtv(silo1, _borrower);
        assertEq(ltvSilo1, expectedLtv);
    }

    /*
        forge test -vvv --ffi --mt test_SiloLens_getFeesAndFeeReceivers
    */
    function test_SiloLens_getFeesAndFeeReceivers() public {
        string memory chainAlias = ChainsLib.chainAlias();
        address daoFeeReceiverConfig = VeSiloDeployments.get(VeSiloContracts.FEE_DISTRIBUTOR, chainAlias);

        // hardcoded in the silo config for the local testing
        address deployerFeeReceiverConfig = 0xdEDEDEDEdEdEdEDedEDeDedEdEdeDedEdEDedEdE;

        vm.warp(block.timestamp + 300 days);

        address daoFeeReceiver;
        address deployerFeeReceiver;
        uint256 daoFee;
        uint256 deployerFee;

        (daoFeeReceiver, deployerFeeReceiver, daoFee, deployerFee) = siloLens.getFeesAndFeeReceivers(silo0);

        assertEq(daoFeeReceiver, daoFeeReceiverConfig);
        assertEq(deployerFeeReceiver, deployerFeeReceiverConfig);
        assertEq(daoFee, 150000000000000000);
        assertEq(deployerFee, 100000000000000000);

        (daoFeeReceiver, deployerFeeReceiver, daoFee, deployerFee) = siloLens.getFeesAndFeeReceivers(silo1);

        assertEq(daoFeeReceiver, daoFeeReceiverConfig);
        assertEq(deployerFeeReceiver, deployerFeeReceiverConfig);
        assertEq(daoFee, 150000000000000000);
        assertEq(deployerFee, 100000000000000000);
    }

    /*
        forge test -vvv --ffi --mt test_SiloLens_collateralBalanceOfUnderlying
    */
    function test_SiloLens_collateralBalanceOfUnderlying() public {
        uint256 borrowerCollateralSilo0 = siloLens.collateralBalanceOfUnderlying(silo0, _depositor);
        assertEq(borrowerCollateralSilo0, 0);

        uint256 borrowerCollateralSilo1 = siloLens.collateralBalanceOfUnderlying(silo1, _depositor);
        assertEq(borrowerCollateralSilo1, _AMOUNT_COLLATERAL + _AMOUNT_PROTECTED);

        address ignoredAddress = makeAddr("Ignored");

        uint256 borrowerCollateralSilo0Ignored = siloLens.collateralBalanceOfUnderlying(
            silo0, ignoredAddress, _depositor
        );

        assertEq(borrowerCollateralSilo0Ignored, 0);

        uint256 borrowerCollateralSilo1Ignored = siloLens.collateralBalanceOfUnderlying(
            silo1, ignoredAddress, _depositor
        );

        assertEq(borrowerCollateralSilo1Ignored, _AMOUNT_COLLATERAL + _AMOUNT_PROTECTED);
    }

    /*
        forge test -vvv --ffi --mt test_SiloLens_debtBalanceOfUnderlying
    */
    function test_SiloLens_debtBalanceOfUnderlying() public {
        uint256 borrowerDebtSilo0 = siloLens.debtBalanceOfUnderlying(silo0, _borrower);
        assertEq(borrowerDebtSilo0, 0);

        uint256 borrowerDebtSilo1 = siloLens.debtBalanceOfUnderlying(silo1, _borrower);
        assertEq(borrowerDebtSilo1, _AMOUNT_BORROW);

        address ignoredAddress = makeAddr("Ignored");

        uint256 borrowerDebtSilo0Ignored = siloLens.debtBalanceOfUnderlying(
            silo0, ignoredAddress, _borrower
        );

        assertEq(borrowerDebtSilo0Ignored, 0);

        uint256 borrowerDebtSilo1Ignored = siloLens.debtBalanceOfUnderlying(
            silo1, ignoredAddress, _borrower
        );

        assertEq(borrowerDebtSilo1Ignored, _AMOUNT_BORROW);
    }
}
