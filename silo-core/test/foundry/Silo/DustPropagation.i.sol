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

    function setUp() public {
        siloConfig = _setUpLocalFixture();

        // we cresting debt on silo1, because lt there is 85 and in silo0 95, so it is easier to test because of dust
        _depositCollateral(COLLATERAL, BORROWER, !SAME_TOKEN);
        vm.prank(BORROWER);
        silo0.borrow(DEBT, BORROWER, BORROWER, SAME_TOKEN);

        uint256 timeForward = 120 days;
        vm.warp(block.timestamp + timeForward);
        assertGt(silo0.getLtv(BORROWER), 1e18, "expect bad debt");
        assertEq(silo0.getLiquidity(), 0, "with bad debt and no depositors, no liquidity");

        (
            , uint256 debtToRepay
        ) = partialLiquidation.maxLiquidation(address(silo0), BORROWER);

        token0.mint(address(this), debtToRepay);
        token0.approve(address(silo0), debtToRepay);
        bool receiveSToken;


        partialLiquidation.liquidationCall(
            address(silo0), address(token0), address(token0), BORROWER, debtToRepay, receiveSToken
        );

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
    this test is based on: test_liquidationCall_badDebt_partial_1token_noDepositors
    forge test -vv --ffi --mt test_dustPropagation
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
}
