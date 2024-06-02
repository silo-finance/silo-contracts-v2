// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IERC20Errors} from "openzeppelin5/interfaces/draft-IERC6093.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc LeverageSameAssetTest
*/
contract LeverageSameAssetTest is SiloLittleHelper, Test {
    ISilo.CollateralType constant public COLLATERAL = ISilo.CollateralType.Collateral;
    ISilo.CollateralType constant public PROTECTED = ISilo.CollateralType.Protected;

    ISiloConfig public siloConfig;

    address public borrower = makeAddr("borrower");

    event Borrow(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    event Deposit(address indexed sender, address indexed depositor, uint256 assets, uint256 shares);

    function setUp() public {
        siloConfig = _setUpLocalFixture(SiloConfigsNames.ETH_USDC_UNI_V3_SILO_NO_HOOK);

        assertTrue(siloConfig.getConfig(address(silo0)).maxLtv != 0, "we need borrow to be allowed");
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_leverageSameAsset_all_zeros
    */
    function test_leverageSameAsset_all_zeros() public {
        vm.expectRevert(ISilo.ZeroAssets.selector);
        silo0.leverageSameAsset(0, 0, address(0), COLLATERAL);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_leverageSameAsset_zero_depositAssets
    */
    function test_leverageSameAsset_zero_depositAssets() public {
        uint256 depositAssets = 0;
        uint256 anyBorrowAssets = 100e18;

        vm.expectRevert(ISilo.ZeroAssets.selector);
        silo0.leverageSameAsset(depositAssets, anyBorrowAssets, borrower, COLLATERAL);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_leverageSameAsset_zero_borrowAssets
    */
    function test_leverageSameAsset_zero_borrowAssets() public {
        uint256 depositAssets = 100e18;
        uint256 zeroBorrowAssets = 0;

        vm.expectRevert(ISilo.ZeroAssets.selector);
        silo0.leverageSameAsset(depositAssets, zeroBorrowAssets, borrower, COLLATERAL);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_leverageSameAsset_noAllowanceDebtToken
    */
    function test_leverageSameAsset_noAllowanceDebtToken() public {
        uint256 depositAssets = 100e18;
        uint256 anyBorrowAssets = 100e18;

        vm.expectRevert(abi.encodeWithSelector(
            IERC20Errors.ERC20InsufficientAllowance.selector,
            address(this),
            0,
            anyBorrowAssets
        ));

        silo0.leverageSameAsset(depositAssets, anyBorrowAssets, borrower, COLLATERAL);
    }
    
    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_leverageSameAsset_revertLeverageTooHigh
    */
    function test_leverageSameAsset_revertLeverageTooHigh() public {
        uint256 depositAssets = 100e18;

        _mintAndApprove(address(silo0), token0, borrower, depositAssets);

        uint256 maxLtv = siloConfig.getConfig(address(silo0)).maxLtv;

        // 1 wei above max
        uint256 borrowAssets = maxLtv * depositAssets / 1e18 + 1;

        vm.prank(borrower);
        vm.expectRevert(ISilo.LeverageTooHigh.selector);
        silo0.leverageSameAsset(depositAssets, borrowAssets, borrower, COLLATERAL);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_leverageSameAsset_maxWithEvents
    */
    function test_leverageSameAsset_maxWithEvents() public {
        uint256 depositAssets = 100e18;

        _mintAndApprove(address(silo0), token0, borrower, depositAssets);

        uint256 maxLtv = siloConfig.getConfig(address(silo0)).maxLtv;

        uint256 maxBorrowAssets = maxLtv * depositAssets / 1e18;

        vm.expectEmit(true, true, true, true);
        emit Borrow(borrower, borrower, borrower, maxBorrowAssets, maxBorrowAssets);

        vm.expectEmit(true, true, true, true);
        emit Deposit(borrower, borrower, depositAssets, depositAssets);

        vm.prank(borrower);
        silo0.leverageSameAsset(depositAssets, maxBorrowAssets, borrower, COLLATERAL);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_leverageSameAsset_collateral
    */
    function test_leverageSameAsset_collateral() public {
        uint256 depositAssets = 100e18;
        uint256 borrowAssets = 50e18;

        _mintAndApprove(address(silo0), token0, borrower, depositAssets);

        uint256 liquidity = silo0.getRawLiquidity();

        assertEq(liquidity, 0, "no liquidity before leverageSameAsset");

        (
            address protectedShareToken,
            address collateralShareToken,
            address debtShareToken
        ) = siloConfig.getShareTokens(address(silo0));

        uint256 protectedShareTokenBalance = IERC20(protectedShareToken).balanceOf(borrower);
        uint256 collateralShareTokenBalance = IERC20(collateralShareToken).balanceOf(borrower);
        uint256 debtShareTokenBalance = IERC20(debtShareToken).balanceOf(borrower);

        assertEq(protectedShareTokenBalance, 0, "no protectedShareTokenBalance before leverageSameAsset");
        assertEq(collateralShareTokenBalance, 0, "no collateralShareTokenBalance before leverageSameAsset");
        assertEq(debtShareTokenBalance, 0, "no debtShareTokenBalance before leverageSameAsset");

        vm.prank(borrower);
        silo0.leverageSameAsset(depositAssets, borrowAssets, borrower, COLLATERAL);

        liquidity = silo0.getRawLiquidity();

        assertEq(liquidity, depositAssets - borrowAssets, "unexpected liquidity after leverageSameAsset");

        protectedShareTokenBalance = IERC20(protectedShareToken).balanceOf(borrower);
        collateralShareTokenBalance = IERC20(collateralShareToken).balanceOf(borrower);
        debtShareTokenBalance = IERC20(debtShareToken).balanceOf(borrower);

        assertEq(protectedShareTokenBalance, 0, "no protectedShareTokenBalance after leverageSameAsset");
        
        assertEq(
            collateralShareTokenBalance,
            depositAssets,
            "unexpected collateralShareTokenBalance after leverageSameAsset"
        );

        assertEq(
            debtShareTokenBalance,
            depositAssets - borrowAssets,
            "unexpected debtShareTokenBalance after leverageSameAsset"
        );
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_leverageSameAsset_protected
    */
    function test_leverageSameAsset_protected() public {
        uint256 depositAssets = 100e18;
        uint256 borrowAssets = 50e18;

        _mintAndApprove(address(silo0), token0, borrower, depositAssets);

        uint256 liquidity = silo0.getRawLiquidity();

        assertEq(liquidity, 0, "no liquidity before leverageSameAsset");

        (
            address protectedShareToken,
            address collateralShareToken,
            address debtShareToken
        ) = siloConfig.getShareTokens(address(silo0));

        uint256 protectedShareTokenBalance = IERC20(protectedShareToken).balanceOf(borrower);
        uint256 collateralShareTokenBalance = IERC20(collateralShareToken).balanceOf(borrower);
        uint256 debtShareTokenBalance = IERC20(debtShareToken).balanceOf(borrower);

        assertEq(protectedShareTokenBalance, 0, "no protectedShareTokenBalance before leverageSameAsset");
        assertEq(collateralShareTokenBalance, 0, "no collateralShareTokenBalance before leverageSameAsset");
        assertEq(debtShareTokenBalance, 0, "no debtShareTokenBalance before leverageSameAsset");

        vm.prank(borrower);
        silo0.leverageSameAsset(depositAssets, borrowAssets, borrower, PROTECTED);

        liquidity = silo0.getRawLiquidity();

        assertEq(liquidity, 0, "unexpected liquidity after leverageSameAsset");

        protectedShareTokenBalance = IERC20(protectedShareToken).balanceOf(borrower);
        collateralShareTokenBalance = IERC20(collateralShareToken).balanceOf(borrower);
        debtShareTokenBalance = IERC20(debtShareToken).balanceOf(borrower);

        assertEq(
            protectedShareTokenBalance,
            depositAssets,
            "unexpected protectedShareTokenBalance after leverageSameAsset"
        );
        
        assertEq(
            collateralShareTokenBalance,
            0,
            "no collateralShareTokenBalance after leverageSameAsset"
        );

        assertEq(
            debtShareTokenBalance,
            depositAssets - borrowAssets,
            "unexpected debtShareTokenBalance after leverageSameAsset"
        );
    }

    function _mintAndApprove(address _silo, MintableToken _token, address _to, uint256 _amount) internal {
        _token.mint(_to, _amount);

        vm.prank(_to);
        IERC20(address(_token)).approve(_silo, _amount);
    }
}
