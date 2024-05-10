// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IInterestRateModel} from "silo-core/contracts/interfaces/IInterestRateModel.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {AssetTypes} from "silo-core/contracts/lib/AssetTypes.sol";

import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";
import {MintableToken} from "../_common/MintableToken.sol";


/*
    forge test -vv --ffi --mc LiquidationCall1TokenTest
*/
contract DustPropagationTest is SiloLittleHelper, Test {
    using SiloLensLib for ISilo;

    address constant BORROWER = address(0x123);
    uint256 constant COLLATERAL = 10e18;
    uint256 constant DEBT = 7.5e18;
    bool constant SAME_TOKEN = true;
    uint256 constant DUST_LEFT = 4;

    ISiloConfig siloConfig;

    /*
    this test is based on: test_liquidationCall_badDebt_partial_1token_noDepositors
    TODO create version of test where we modify storage and set some 1e5 value, to see how numbers behave
    */
    function setUp() public {
        siloConfig = _setUpLocalFixture();

        _printState("initial state");

        // we cresting debt on silo0, because lt there is 85 and in silo0 95, so it is easier to test because of dust
        _depositCollateral(COLLATERAL, BORROWER, !SAME_TOKEN);
        _printState("after deposit collateral");

        vm.prank(BORROWER);
        silo0.borrow(DEBT, BORROWER, BORROWER, SAME_TOKEN);
        _printState("after borrow");

        uint256 timeForward = 120 days;
        vm.warp(block.timestamp + timeForward);
        assertGt(silo0.getLtv(BORROWER), 1e18, "expect bad debt");
        assertEq(silo0.getLiquidity(), 0, "with bad debt and no depositors, no liquidity");
        _printState("after time forward");

        (
            , uint256 debtToRepay
        ) = partialLiquidation.maxLiquidation(address(silo0), BORROWER);

        token0.mint(address(this), debtToRepay);
        token0.approve(address(silo0), debtToRepay);
        bool receiveSToken;


        partialLiquidation.liquidationCall(
            address(silo0), address(token0), address(token0), BORROWER, debtToRepay, receiveSToken
        );
        _printState("after liquidation");


        assertTrue(silo0.isSolvent(BORROWER), "user is solvent after liquidation");

        silo0.withdrawFees();

        ISiloConfig.ConfigData memory configData = siloConfig.getConfig(address(silo0));

        assertEq(IShareToken(configData.debtShareToken).totalSupply(), 0, "expected debtShareToken burned");
        assertEq(IShareToken(configData.collateralShareToken).totalSupply(), 0, "expected collateralShareToken burned");
        assertEq(IShareToken(configData.protectedShareToken).totalSupply(), 0, "expected protectedShareToken 0");
        assertEq(silo0.getDebtAssets(), 0, "total debt == 0");

        assertEq(token0.balanceOf(address(silo0)), DUST_LEFT, "no balance after withdraw fees (except dust!)");
        assertEq(silo0.total(AssetTypes.COLLATERAL), DUST_LEFT, "storage AssetType.Collateral");
        assertEq(silo0.getCollateralAssets(), DUST_LEFT, "total collateral == 4, dust!");
        assertEq(silo0.getLiquidity(), DUST_LEFT, "getLiquidity == 4, dust!");

        emit log_named_uint("there is no users in silo, but balance is", DUST_LEFT);
    }

    /*
    forge test -vv --ffi --mt test_dustPropagation_oneUser
    */
    function test_dustPropagation_oneUser() public {
        address user1 = makeAddr("user1");

        /*
            user must deposit at least dust + 1, because otherwise math revert with zeroShares
            situation is like this: we have 0 shares, and 4 assets, to get 1 share, min of 5 assets is required
            so we have situation where assets > shares from begin, not only after interest
            and looks like this dust will be locked forever in Silo because in our SiloMathLib we have:

            unchecked {
                // I think we can afford to uncheck +1
                (totalShares, totalAssets) = _assetType == ISilo.AssetType.Debt
                    ? (_totalShares, _totalAssets)
                    : (_totalShares + _DECIMALS_OFFSET_POW, _totalAssets + 1);
            }

            if (totalShares == 0 || totalAssets == 0) return _assets;

            ^ we never enter into this `if` for non debt assets, because we always adding +1 for both variables
            and this is why this dust will be forever locked in silo.
            Atm the only downside I noticed: it creates "minimal deposit" situation.
        */
        uint256 shares1 = _deposit(DUST_LEFT + 1, user1);
        emit log_named_uint("[user1] shares1", shares1);

        uint256 maxWithdraw1 = silo0.maxWithdraw(user1);
        assertEq(maxWithdraw1, DUST_LEFT + 1, "[user1] maxWithdraw");
        assertEq(_redeem(shares1, user1), DUST_LEFT + 1, "[user1] withdrawn assets");

        assertEq(silo0.getLiquidity(), DUST_LEFT, "getLiquidity == 4, dust!");
    }

    /*
    forge test -vv --ffi --mt test_dustPropagation_twoUsers
    */
    function test_dustPropagation_twoUsers() public {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        uint256 shares1 = _deposit(DUST_LEFT + 1, user1);
        emit log_named_uint("[user1] shares1", shares1);

        uint256 shares2 = _deposit(DUST_LEFT + 1, user2);
        emit log_named_uint("[user2] shares2", shares2);

        uint256 maxWithdraw1 = silo0.maxWithdraw(user1);
        uint256 maxWithdraw2 = silo0.maxWithdraw(user2);

        assertEq(maxWithdraw1, DUST_LEFT + 1, "[user1] maxWithdraw");
        assertEq(maxWithdraw2, DUST_LEFT + 1, "[user2] maxWithdraw");

        assertEq(_redeem(shares1, user1), DUST_LEFT + 1, "[user1] withdrawn assets");
        assertEq(_redeem(shares2, user2), DUST_LEFT + 1, "[user2] withdrawn assets");

        assertEq(silo0.getLiquidity(), DUST_LEFT, "getLiquidity == 4, dust!");
    }

    /*
    forge test -vv --ffi --mt test_dustPropagation_noInterest_twoUsers_fuzz

    theory: DIFF in loos can not be higher than dust
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_dustPropagation_noInterest_twoUsers_fuzz(
        uint128 deposit1, uint128 deposit2
    ) public {
//        (uint128 deposit1, uint128 deposit2) = (25550723675487705537526, 42);
        vm.assume(deposit1 > DUST_LEFT);
        vm.assume(deposit2 > DUST_LEFT);

        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        uint256 shares1 = _deposit(deposit1, user1);
        uint256 shares2 = _deposit(deposit2, user2);

        emit log_named_uint("shares1", shares1);
        emit log_named_uint("shares2", shares2);

        uint256 maxWithdraw1 = silo0.maxWithdraw(user1);
        uint256 maxWithdraw2 = silo0.maxWithdraw(user2);

        bool user1GetsMore = maxWithdraw1 > deposit1;
        bool user2GetsMore = maxWithdraw2 > deposit2;

        emit log_named_string("user1 will get", user1GetsMore ? "MORE" : "LESS");
        emit log_named_uint("    deposit1", deposit1);
        emit log_named_uint("maxWithdraw1", maxWithdraw1);
        emit log_named_string("user2 will get", user2GetsMore ? "MORE" : "LESS");
        emit log_named_uint("    deposit2", deposit2);
        emit log_named_uint("maxWithdraw2", maxWithdraw2);

        if (!user1GetsMore) {
            assertLe(deposit1 - maxWithdraw1, DUST_LEFT, "[user1] maxWithdraw can be less by DUST_LEFT");
        }

        if (!user2GetsMore) {
            assertLe(deposit2 - maxWithdraw2, DUST_LEFT, "[user2] maxWithdraw can be less by DUST_LEFT");
        }

        uint256 withdrawn1 = _redeem(shares1, user1);
        emit log_named_uint("withdrawn1", withdrawn1);
        assertEq(withdrawn1, maxWithdraw1, "[user1] max should match real withdrawn");

        uint256 withdrawn2 = _redeem(shares2, user2);
        emit log_named_uint("withdrawn2", withdrawn2);
        assertEq(withdrawn2, maxWithdraw2, "[user2] max should match real withdrawn");

        bool user1GotMore = withdrawn1 > deposit1;
        bool user2GotMore = withdrawn2 > deposit2;

        uint256 diff1 = user1GotMore ? withdrawn1 - deposit1 : deposit1 - withdrawn1;
        uint256 diff2 = user2GotMore ? withdrawn2 - deposit2 : deposit2 - withdrawn2;

        emit log_named_uint("diff1", diff1);
        emit log_named_uint("diff2", diff2);

        if (!user1GotMore) {
            assertLe(diff1, DUST_LEFT, "[user1] withdrawn assets can be off by DUST_LEFT max");
        }

        if (!user2GotMore) {
            assertLe(diff2, DUST_LEFT, "[user2] withdrawn assets can be off by DUST_LEFT max");
        }

        emit log_named_uint("dust was", DUST_LEFT);
        emit log_named_uint("silo0.getLiquidity() is now", silo0.getLiquidity());

        assertLe(silo0.getLiquidity() - DUST_LEFT, 2, "without interest dust should not go up more than 2?");
    }

    function _printState(string memory _title) private {
        (
            ISiloConfig.ConfigData memory collateralConfig,,
        ) = siloConfig.getConfigs(address(silo0), BORROWER, 0 /* always 0 for external calls */);

        emit log_named_string("================ ", _title);

        emit log_named_decimal_uint("borrower LTV ", silo0.getLtv(BORROWER), 16);
        emit log_named_decimal_uint("borrower collateral shares ", IShareToken(collateralConfig.collateralShareToken).balanceOf(BORROWER), 18);
        emit log_named_decimal_uint("borrower debt (max repay)", silo0.maxRepay(BORROWER), 18);
        emit log_named_decimal_uint("silo collateral assets RAW", silo0.total(AssetTypes.COLLATERAL), 18);
        emit log_named_decimal_uint("silo collateral assets with interests", silo0.getCollateralAssets(), 18);
        emit log_named_decimal_uint("silo liquidity", silo0.getLiquidity(), 18);
        emit log_named_decimal_uint("balanceOf(silo)", token0.balanceOf(address(silo0)), 18);

        (
            uint256 collateralToWithdraw, uint256 debtToRepay
        ) = partialLiquidation.maxLiquidation(address(silo0), BORROWER);

        if (debtToRepay != 0) {
            emit log_named_decimal_uint("liquidation possible, collateralToWithdraw", collateralToWithdraw, 18);
            emit log_named_decimal_uint("liquidation possible, debtToRepay", debtToRepay, 18);
        }

        emit log("_____");


    }
}
