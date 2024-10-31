// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ISilo} from "silo-core/contracts/Silo.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {Actor} from "../../utils/Actor.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";
import {TestERC20} from "../../utils/mocks/TestERC20.sol";

/// @title BorrowingHandler
/// @notice Handler test contract for a set of actions
contract BorrowingHandler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /* 
    
    E.g. num of active pools
    uint256 public activePools;
        
    */

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function borrow(uint256 _assets, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address target = _getRandomSilo(j);

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(ISilo.borrow.selector, _assets, receiver, address(actor)));

        // POST-CONDITIONS

        if (success) {
            _after();

            assertEq(
                defaultVarsBefore[target].debtAssets + _assets, defaultVarsAfter[target].debtAssets, LENDING_HSPOST_A
            );

            assertEq(defaultVarsAfter[target].balance + _assets, defaultVarsBefore[target].balance, BORROWING_HSPOST_O);
        }
    }

    function borrowSameAsset(uint256 _assets, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address target = _getRandomSilo(j);

        _before();
        (success, returnData) = actor.proxy(
            target, abi.encodeWithSelector(ISilo.borrowSameAsset.selector, _assets, receiver, address(actor))
        );

        if (success) {
            _after();

            assertEq(
                defaultVarsBefore[target].debtAssets + _assets, defaultVarsAfter[target].debtAssets, LENDING_HSPOST_A
            );

            assertEq(defaultVarsAfter[target].balance + _assets, defaultVarsBefore[target].balance, BORROWING_HSPOST_O);
        }
    }

    function borrowShares(uint256 _shares, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address target = _getRandomSilo(j);

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(ISilo.borrowShares.selector, _shares, receiver, address(actor)));

        if (success) {
            _after();

            assertGe(
                defaultVarsAfter[target].userDebtShares, defaultVarsBefore[target].userDebtShares, BORROWING_HSPOST_Q
            );

            assertGe(defaultVarsAfter[target].userBalance, defaultVarsBefore[target].userBalance, BORROWING_HSPOST_R);
        }
    }

    function repay(uint256 _assets, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address borrower = _getRandomActor(i);

        _setTargetActor(borrower);

        address target = _getRandomSilo(j);

        uint256 maxRepay = ISilo(target).maxRepay(borrower);

        _before();
        (success, returnData) = actor.proxy(target, abi.encodeWithSelector(ISilo.repay.selector, _assets, borrower));

        if (success) {
            _after();

            assertGe(maxRepay, _assets, BORROWING_HSPOST_G);
            assertLe(defaultVarsAfter[target].userDebt, defaultVarsBefore[target].userDebt, BORROWING_HSPOST_H);
        }
    }

    function repayShares(uint256 _shares, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address borrower = _getRandomActor(i);

        _setTargetActor(borrower);

        address target = _getRandomSilo(j);

        uint256 debtAmount = ISilo(target).maxRepay(borrower);

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(ISilo.repayShares.selector, _shares, borrower));

        if (success) {
            _after();

            if (_shares >= debtAmount) {
                assertEq(IERC20(siloConfig.getDebtSilo(borrower)).balanceOf(borrower), 0, BORROWING_HSPOST_B);
            }
            assertLe(defaultVarsAfter[target].userDebt, defaultVarsBefore[target].userDebt, BORROWING_HSPOST_H);
        }
    }

    function switchCollateralToThisSilo(uint8 i) external setup {
        bool success;
        bytes memory returnData;

        address target = _getRandomSilo(i);

        _before();
        (success, returnData) = actor.proxy(target, abi.encodeWithSelector(ISilo.switchCollateralToThisSilo.selector));

        if (success) {
            _after();
        }
    }

    function transitionCollateral(uint256 _shares, uint8 i, uint8 j, uint8 k) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address owner = _getRandomActor(i);

        _setTargetActor(owner);

        address target = _getRandomSilo(j);

        ISilo.CollateralType _collateralType = ISilo.CollateralType(k % 2);

        uint256 liquidity = ISilo(target).getLiquidity();

        (uint256 collateralAssets,) = ISilo(target).getCollateralAndDebtTotalsStorage();

        console.log("collateralAssets: %d", collateralAssets);

        uint256 _assets = ISilo(target).convertToAssets(
            _shares,
            (_collateralType == ISilo.CollateralType.Protected)
                ? ISilo.AssetType.Protected
                : ISilo.AssetType.Collateral
        );

        _before();
        (success, returnData) = actor.proxy(
            target, abi.encodeWithSelector(ISilo.transitionCollateral.selector, _shares, owner, _collateralType)
        );

        // POST-CONDITIONS

        if (defaultVarsBefore[target].isSolvent && _collateralType == ISilo.CollateralType.Protected) {
            // assertTrue(success, BORROWING_HSPOST_L); // @audit-issue fails when amount is 0
        }

        if (success) {
            _after();

            if (_collateralType != ISilo.CollateralType.Protected) {
                assertGe(liquidity, _assets, LENDING_HSPOST_D);
            }
            assertLe(defaultVarsAfter[target].userAssets, defaultVarsBefore[target].userAssets, BORROWING_HSPOST_J);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         OWNER ACTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          PROPERTIES                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_BORROWING_HSPOST_D(uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address borrower = _getRandomActor(i);

        address target = _getRandomSilo(j);

        uint256 debtAmount = ISilo(target).maxRepay(borrower);

        (, address debtAsset) = siloConfig.getDebtShareTokenAndAsset(target);

        if (debtAmount > IERC20(debtAsset).balanceOf(borrower)) {
            TestERC20(debtAsset).mint(address(actor), IERC20(debtAsset).balanceOf(borrower));
        }

        _before();
        (success, returnData) = actor.proxy(target, abi.encodeWithSelector(ISilo.repay.selector, debtAmount, borrower));

        if (debtAmount > 0) {
            assertTrue(success, BORROWING_HSPOST_D);
            assertEq(ISilo(target).maxRepay(borrower), 0, BORROWING_HSPOST_D);
        }

        if (success) {
            _after();
        }
    }

    function assertBORROWING_HSPOST_F(uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address target = _getRandomSilo(j);

        uint256 maxBorrow = ISilo(target).maxBorrow(receiver);

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(ISilo.borrow.selector, maxBorrow, receiver, address(actor)));

        if (maxBorrow > 0) {
            //assertTrue(success, BORROWING_HSPOST_F); TODO remove comment when test_replayassertBORROWING_HSPOST_F is fixed
        }

        if (success) {
            _after();
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
