// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {MaxLiquidationCommon} from "./MaxLiquidationCommon.sol";

/*
    forge test -vv --ffi --mc MaxLiquidationCapTest

    this tests are for "normal" case,
    where user became insolvent and we can partially liquidate
*/
contract MaxLiquidationCapTest is MaxLiquidationCommon {
    using SiloLensLib for ISilo;

    bool private constant _BAD_DEBT = false;

    /*
    forge test -vv --ffi --mt test_maxLiquidation_cap_1token
    */
    function test_maxLiquidation_cap_1token() public {
        _createDebtForBorrower(1e18, true);

        _moveTimeUntilInsolvent();
        _assertBorrowerIsNotSolvent(false);

        (
            uint256 collateralToLiquidate,, bool sTokenRequired
        ) = partialLiquidation.maxLiquidation(borrower);

        emit log_named_uint("            getLiquidity", silo1.getLiquidity());
        emit log_named_uint("collateralToLiquidate #1", collateralToLiquidate);

        assertTrue(!sTokenRequired, "sTokenRequired NOT required because it is partial liquidation");

        _moveTimeUntilBadDebt();
        _assertBorrowerIsNotSolvent(true);

        (
            uint256 collateralToLiquidate2, uint256 maxDebtToCover2, bool sTokenRequired2
        ) = partialLiquidation.maxLiquidation(borrower);

        emit log_named_uint("            getLiquidity", silo1.getLiquidity());
        emit log_named_uint("collateralToLiquidate #2", collateralToLiquidate2);

        assertTrue(sTokenRequired2, "sTokenRequired required because we in bad debt");

        emit log_named_uint("maxDebtToCover2", maxDebtToCover2);
        emit log_named_uint("balance silo", token1.balanceOf(address(silo1)));
        emit log_named_uint("balance this", token1.balanceOf(address(this)));

        // this execution will pass even when sTokenRequired2==true, because repay will cover missing liquidity
        partialLiquidation.liquidationCall(
            address(token1),
            address(token1),
            borrower,
            maxDebtToCover2,
            false // receiveStoken
        );
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_cap_2tokens
    */
    function test_maxLiquidation_cap_2tokens() public {
        _createDebtForBorrower(1e18, false);

        _moveTimeUntilInsolvent();
        _assertBorrowerIsNotSolvent(false);

        (
            uint256 collateralToLiquidate, uint256 maxDebtToCover, bool sTokenRequired
        ) = partialLiquidation.maxLiquidation(borrower);

        emit log_named_uint("         getLiquidity #1", silo0.getLiquidity());
        emit log_named_uint("collateralToLiquidate #1", collateralToLiquidate);

        assertTrue(!sTokenRequired, "sTokenRequired NOT required because it is partial liquidation");

        vm.startPrank(depositor);
        silo0.borrow(silo0.maxBorrow(depositor), depositor, depositor);
        vm.stopPrank();
        emit log_named_uint("getLiquidity after borrow", silo0.getLiquidity());

        (collateralToLiquidate, maxDebtToCover, sTokenRequired) = partialLiquidation.maxLiquidation(borrower);
        assertTrue(sTokenRequired, "sTokenRequired IS required because we borrowed on silo0");

        vm.expectRevert(ISilo.NotEnoughLiquidity.selector);
        partialLiquidation.liquidationCall(
            address(token0),
            address(token1),
            borrower,
            maxDebtToCover,
            false // receiveStoken
        );

        _deposit(collateralToLiquidate - silo0.getLiquidity(), address(1));

        (,, sTokenRequired) = partialLiquidation.maxLiquidation(borrower);
        assertTrue(sTokenRequired, "sTokenRequired is still required because of -2");

        _deposit(2, address(1));

        (collateralToLiquidate, maxDebtToCover, sTokenRequired) = partialLiquidation.maxLiquidation(borrower);
        assertTrue(!sTokenRequired, "sTokenRequired NOT required because we have 'collateralToLiquidate + 2' in silo0");

        emit log_named_uint("         getLiquidity #2", silo0.getLiquidity());
        emit log_named_uint("collateralToLiquidate #2", collateralToLiquidate);

        partialLiquidation.liquidationCall(
            address(token0),
            address(token1),
            borrower,
            maxDebtToCover,
            false // receiveStoken
        );
    }

    function _withChunks() internal virtual pure override returns (bool) {
        revert("not in use");
    }

    function _executeLiquidation(bool, bool) internal pure override
        returns (uint256, uint256)
    {
        revert("not in use");
    }
}
