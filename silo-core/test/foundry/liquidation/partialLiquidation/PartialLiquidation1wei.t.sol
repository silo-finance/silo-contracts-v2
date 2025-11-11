// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {IERC20Errors} from "openzeppelin5/interfaces/draft-IERC6093.sol";

import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";
import {SiloConfigOverride, SiloFixture} from "../../_common/fixtures/SiloFixture.sol";
import {MintableToken} from "silo-core/test/foundry/_common/MintableToken.sol";

/*
FOUNDRY_PROFILE=core_test forge test -vv --ffi --mc PartialLiquidation1weiTest
*/
contract PartialLiquidation1weiTest is SiloLittleHelper, Test {
    ISiloConfig siloConfig;

    address oracle = makeAddr("Oracle");

    function setUp() public {
        token0 = new MintableToken(8);
        token1 = new MintableToken(10);

        token0.setOnDemand(true);
        token1.setOnDemand(true);

        vm.mockCall(oracle, abi.encodeWithSelector(ISiloOracle.quoteToken.selector), abi.encode(address(token1)));

        SiloConfigOverride memory overrides;
        overrides.token0 = address(token0);
        overrides.token1 = address(token1);
        overrides.solvencyOracle0 = oracle;
        overrides.maxLtvOracle0 = oracle;

        SiloFixture siloFixture = new SiloFixture();

        address hook;
        (, silo0, silo1,,, hook) = siloFixture.deploy_local(overrides);

        partialLiquidation = IPartialLiquidation(hook);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_1wei_collateral_borrowNotPossible_fuzz
    */
    /// forge-config: core_test.fuzz.runs = 10000
    function test_1wei_collateral_borrowNotPossible_fuzz(uint32 _amount, uint32 _burn) public {
        _depositAndBurn(_amount, _burn, ISilo.CollateralType.Collateral);

        _mockQuote(1, 1e10);
        address borrower = makeAddr("Borrower");
        vm.prank(borrower);
        uint256 shares = silo0.deposit(1, borrower);
        vm.stopPrank();

        _depositForBorrow(1e18, address(3));

        console2.log("shares", silo0.balanceOf(borrower));
        console2.log("ratio", silo0.convertToShares(1));

        uint256 maxWithdraw = silo0.maxWithdraw(borrower);
        uint256 maxRedeem = silo0.maxRedeem(borrower);
        uint256 maxBorrow = silo1.maxBorrow(borrower);

        console2.log("maxWithdraw", maxWithdraw);
        console2.log("maxRedeem", maxRedeem);
        console2.log("maxBorrow", maxBorrow);

        assertLe(maxWithdraw, 1, "maxWithdraw should be 0 or 1");
        assertLe(maxRedeem, shares, "maxRedeem should be not more than actual shares");
        assertEq(maxBorrow, 0, "maxBorrow should be 0");
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_1wei_asset_protected
    */
    /// forge-config: core_test.fuzz.runs = 10000
    function test_1wei_asset_protected_fuzz(uint32 _amount, uint32 _burn) public {
        _depositAndBurn(_amount, _burn, ISilo.CollateralType.Protected);

        _depositForBorrow(1e18, address(3));

        // in BTC/USDC 1e8 BTC == 100000e18 USDC,
        // so 1 wei BTC = 100000e18 USDC / 1e8 = 1e10 USDC
        uint256 price = 1e10;
        _mockQuote(1, price);

        address borrower = makeAddr("Borrower");
        vm.prank(borrower);
        uint256 shares = silo0.deposit(1, borrower, ISilo.CollateralType.Protected);
        vm.stopPrank();

        uint256 maxWithdraw = silo0.maxWithdraw(borrower, ISilo.CollateralType.Protected);
        uint256 maxRedeem = silo0.maxRedeem(borrower, ISilo.CollateralType.Protected);
        console2.log("maxWithdraw", maxWithdraw);
        console2.log("maxRedeem", maxRedeem);

        assertLe(maxWithdraw, 1, "maxWithdraw should be <= 1");
        assertLe(maxRedeem, shares, "maxRedeem should be not more than actual shares");

        uint256 maxBorrow = silo1.maxBorrow(borrower);
        console2.log("maxBorrow >>>>>>", maxBorrow);
        assertLt(maxBorrow, price, "maxBorrow should be not more than price of 1 wei");

        vm.assume(maxBorrow > 0);

        _borrow(maxBorrow, borrower);
        maxRedeem = silo0.maxRedeem(borrower, ISilo.CollateralType.Protected);
        console2.log("maxRedeem", maxRedeem);

        (address protectedShareToken,, address debtShareToken) = silo0.config().getShareTokens(address(silo0));

        vm.prank(borrower);
        vm.expectRevert(IShareToken.SenderNotSolventAfterTransfer.selector);
        IShareToken(protectedShareToken).transfer(address(1), 1);
        vm.stopPrank();

        _mockQuote(1, 8e9); // price DROP
        assertFalse(silo1.isSolvent(borrower), "borrower should be ready to liquidate");

        (uint256 collateralToLiquidate, uint256 debtToRepay, bool sTokenRequired) =
            partialLiquidation.maxLiquidation(borrower);

        console2.log("collateralToLiquidate", collateralToLiquidate);
        console2.log("debtToRepay", debtToRepay);
        console2.log("sTokenRequired", sTokenRequired);

        uint256 ltv = siloLens.getLtv(silo0, borrower);
        emit log_named_decimal_uint("ltv", ltv, 16);

        partialLiquidation.liquidationCall(address(token0), address(token1), borrower, debtToRepay, false);

        uint256 btcBalance = token0.balanceOf(address(this));
        console2.log("BTC balance", btcBalance);
        assertEq(btcBalance, 1, "BTC balance is collateral after liquidation");

        assertEq(IShareToken(protectedShareToken).balanceOf(borrower), 0, "protected shares are liquidated fully");
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0, "debt repaid fully");
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_1wei_shares_protected
    */
    /// forge-config: core_test.fuzz.runs = 10000
    function test_1wei_shares_protected_fuzz(uint32 _amount, uint32 _burn) public {
        // we should not have any situatio nwhere ratio for protected changes, but just for the sake of the test
        _depositAndBurn(_amount, _burn, ISilo.CollateralType.Protected);

        _depositForBorrow(1e18, address(3));

        address borrower = makeAddr("Borrower");
        vm.prank(borrower);
        silo0.mint(1, borrower, ISilo.CollateralType.Protected);
        vm.stopPrank();

        uint256 maxWithdraw = silo0.maxWithdraw(borrower, ISilo.CollateralType.Protected);
        uint256 maxRedeem = silo0.maxRedeem(borrower, ISilo.CollateralType.Protected);
        uint256 maxBorrow = silo1.maxBorrow(borrower);

        console2.log("maxWithdraw", maxWithdraw);
        console2.log("maxRedeem", maxRedeem);
        console2.log("maxBorrow", maxBorrow);

        assertEq(maxBorrow, 0, "maxBorrow should be 0");
    }

    function _mockQuote(uint256 _amountIn, uint256 _price) public {
        vm.mockCall(
            oracle, abi.encodeWithSelector(ISiloOracle.quote.selector, _amountIn, address(token0)), abi.encode(_price)
        );
    }

    function _depositAndBurn(uint256 _amount, uint256 _burn, ISilo.CollateralType _collateralType) public {
        if (_amount == 0) return;

        uint256 shares = _deposit(_amount, address(this), _collateralType);
        vm.assume(shares >= _burn);

        if (_burn != 0) {
            (address protectedShareToken, address collateralShareToken,) =
                silo0.config().getShareTokens(address(silo0));
            address token =
                _collateralType == ISilo.CollateralType.Protected ? protectedShareToken : collateralShareToken;

            vm.prank(address(silo0));
            IShareToken(token).burn(address(this), address(this), _burn);
        }
    }
}
