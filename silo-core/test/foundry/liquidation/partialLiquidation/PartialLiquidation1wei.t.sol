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

    function _setUp() public {
        // siloConfig = _setUpLocalFixture(SiloConfigsNames.SILO_LOCAL_NO_ORACLE_DEFAULTING);
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
        // overrides.configName = SiloConfigsNames.SILO_LOCAL_BEFORE_CALL;

        SiloFixture siloFixture = new SiloFixture();

        address hook;
        (, silo0, silo1,,,hook) = siloFixture.deploy_local(overrides);

        partialLiquidation = IPartialLiquidation(hook);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_1wei_collateral
    */
    function test_1wei_collateral() public {
        _setUp();

        address borrower = makeAddr("Borrower");
        vm.prank(borrower);
        uint256 shares = silo0.deposit(1, borrower);
        vm.stopPrank();

        console2.log("shares", silo0.balanceOf(borrower));
        uint256 maxWithdraw = silo0.maxWithdraw(borrower);
        uint256 maxRedeem = silo0.maxRedeem(borrower);
        console2.log("maxWithdraw", maxWithdraw);
        console2.log("maxRedeem", maxRedeem);

        assertEq(maxWithdraw, 0, "maxWithdraw should be 0");
        assertEq(maxRedeem, 0, "maxRedeem should be 0");

        // _depositForBorrow(1e18, address(3));

        // in BTC/USDC 1e8 BTC == 100000e18 USDC,
        // so 1 wei BTC = 100000e18 USDC / 1e8 = 1e10 USDC
        // vm.mockCall(
        //     oracle, 
        //     abi.encodeWithSelector(ISiloOracle.quote.selector, 1, address(token1)),
        //     abi.encode(1e10)
        // );

        // console2.log("maxBorrow", silo1.maxBorrow(borrower));
        // _borrow(silo1.maxBorrow(borrower), borrower);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_1wei_asset_protected
    */
    function test_1wei_asset_protected() public {
        _setUp();

        address borrower = makeAddr("Borrower");
        vm.prank(borrower);
        uint256 shares = silo0.deposit(1, borrower, ISilo.CollateralType.Protected);
        vm.stopPrank();

        uint256 maxWithdraw = silo0.maxWithdraw(borrower, ISilo.CollateralType.Protected);
        uint256 maxRedeem = silo0.maxRedeem(borrower, ISilo.CollateralType.Protected);
        console2.log("maxWithdraw", maxWithdraw);
        console2.log("maxRedeem", maxRedeem);

        assertGt(maxWithdraw, 0, "maxWithdraw should be > 0");
        assertGt(maxRedeem, 0, "maxRedeem should be > 0");

        _depositForBorrow(1e18, address(3));

        // in BTC/USDC 1e8 BTC == 100000e18 USDC,
        // so 1 wei BTC = 100000e18 USDC / 1e8 = 1e10 USDC
        _mockQuote(1, 1e2 * 1.1e18 / 1e18);

        uint256 maxBorrow = silo1.maxBorrow(borrower);
        console2.log("maxBorrow >>>>>>", maxBorrow);
        assertGt(maxBorrow, 0, "maxBorrow should be > 0");

        _borrow(maxBorrow, borrower);
        maxRedeem = silo0.maxRedeem(borrower, ISilo.CollateralType.Protected);
        console2.log("maxRedeem", maxRedeem);

        (address protectedShareToken,,) = silo0.config().getShareTokens(address(silo0));

        vm.prank(borrower);
        vm.expectRevert(IShareToken.SenderNotSolventAfterTransfer.selector);
        IShareToken(protectedShareToken).transfer(address(1), 1);
        vm.stopPrank();

        _mockQuote(1, 8e9);
        assertFalse(silo1.isSolvent(borrower), "borrower should be ready to liquidate");

        (uint256 collateralToLiquidate, uint256 debtToRepay, bool sTokenRequired) = partialLiquidation.maxLiquidation(borrower);

        console2.log("collateralToLiquidate", collateralToLiquidate);
        console2.log("debtToRepay", debtToRepay);
        console2.log("sTokenRequired", sTokenRequired);

        uint256 ltv = siloLens.getLtv(silo0, borrower);
        emit log_named_decimal_uint("ltv", ltv, 16);

        partialLiquidation.liquidationCall(address(token0), address(token1), borrower, debtToRepay, false);


        // by depositing 1 share of protected collateral, we make liquiretion possible?
        silo0.deposit(1, borrower, ISilo.CollateralType.Protected);
        _mockQuote(2, 1e9 * 2);
        ltv = siloLens.getLtv(silo0, borrower);
        emit log_named_decimal_uint("ltv", ltv, 16);

        partialLiquidation.liquidationCall(address(token0), address(token1), borrower, debtToRepay, false);

        console2.log("BTC balance", token0.balanceOf(address(this)));

        // ltv = siloLens.getLtv(silo0, borrower);
        // emit log_named_decimal_uint("ltv", ltv, 16);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_1wei_shares_protected
    */
    function test_1wei_shares_protected() public {
        _setUp();

        address borrower = makeAddr("Borrower");
        vm.prank(borrower);
        uint256 shares = silo0.mint(1, borrower, ISilo.CollateralType.Protected);
        vm.stopPrank();

        uint256 maxWithdraw = silo0.maxWithdraw(borrower, ISilo.CollateralType.Protected);
        uint256 maxRedeem = silo0.maxRedeem(borrower, ISilo.CollateralType.Protected);
        console2.log("maxWithdraw", maxWithdraw);
        console2.log("maxRedeem", maxRedeem);

        _depositForBorrow(1e18, address(3));

        // in BTC/USDC 1e8 BTC == 100000e18 USDC,
        // so 1 wei BTC = 100000e18 USDC / 1e8 = 1e10 USDC
        _mockQuote(1, 1e10);

        console2.log("maxBorrow", silo1.maxBorrow(borrower));
        // _borrow(silo1.maxBorrow(borrower), borrower);
    }

    function _mockQuote(uint256 _amountIn, uint256 _price) public {
        vm.mockCall(
            oracle, 
            abi.encodeWithSelector(ISiloOracle.quote.selector, _amountIn, address(token0)),
            abi.encode(_price)
        );
    }
}
