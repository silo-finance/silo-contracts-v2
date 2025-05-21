// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import {Pretty, Strings} from "../utils/Pretty.sol";
import "forge-std/console.sol";

// Interfaces
import {ISilo} from "silo-core/contracts/Silo.sol";
import {IVaultHandler} from "../handlers/interfaces/IVaultHandler.sol";
import {ISiloHandler} from "../handlers/interfaces/ISiloHandler.sol";
import {IBorrowingHandler} from "../handlers/interfaces/IBorrowingHandler.sol";
import {ILiquidationHandler} from "../handlers/interfaces/ILiquidationHandler.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Test Contracts
import {BaseHooks} from "../base/BaseHooks.t.sol";
import {Actor} from "../utils/Actor.sol";

/// @title Default Before After Hooks
/// @notice Helper contract for before and after hooks
/// @dev This contract is inherited by handlers
abstract contract DefaultBeforeAfterHooks is BaseHooks {
    using Strings for string;
    using Pretty for uint256;
    using Pretty for int256;
    using Pretty for bool;

    struct DefaultVars {
        // ERC4626
        uint256 totalSupply;
        uint256 exchangeRate;
        uint256 totalAssets;
        uint256 supplyCap;
        // Silo
        uint256 debtAssets;
        uint256 collateralAssets;
        uint256 balance;
        uint256 cash;
        uint256 interestRate;
        uint256 borrowCap;
        uint192 daoAndDeployerFees;
        // Borrowing
        uint256 userDebtShares;
        uint256 userDebt;
        uint256 userAssets;
        uint256 userBalance;
        uint256 interestRateTimestamp;
        address borrowerCollateralSilo;
        bool isSolvent;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       HOOKS STORAGE                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    mapping(address => DefaultVars) defaultVarsBefore;
    mapping(address => DefaultVars) defaultVarsAfter;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           SETUP                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Default hooks setup
    function _setUpDefaultHooks() internal {}

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HOOKS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _defaultHooksBefore(address silo) internal {
        _setSiloValues(silo, defaultVarsBefore[silo]);
        _setBorrowingValues(silo, defaultVarsBefore[silo]);
    }

    function _defaultHooksAfter(address silo) internal {
        _setSiloValues(silo, defaultVarsAfter[silo]);
        _setBorrowingValues(silo, defaultVarsAfter[silo]);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           SETTERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _setSiloValues(address silo, DefaultVars storage _defaultVars) internal {
        _defaultVars.totalSupply = ISilo(silo).totalSupply();
        _defaultVars.totalAssets = ISilo(silo).totalAssets();
        _defaultVars.debtAssets = ISilo(silo).getDebtAssets();
        _defaultVars.collateralAssets = ISilo(silo).getCollateralAssets();
        (_defaultVars.daoAndDeployerFees,,,,) = ISilo(silo).getSiloStorage();
    }

    function _setBorrowingValues(address silo, DefaultVars storage _defaultVars) internal {
        (address debtToken, address _asset) = siloConfig.getDebtShareTokenAndAsset(silo);
        _defaultVars.balance = IERC20(_asset).balanceOf(silo);
        _defaultVars.interestRateTimestamp = ISilo(silo).utilizationData().interestRateTimestamp;

        _defaultVars.userDebtShares = IERC20(debtToken).balanceOf(targetActor);
        _defaultVars.userDebt = ISilo(silo).maxRepay(targetActor);
        _defaultVars.userAssets = _getUserAssets(silo, targetActor);
        _defaultVars.userBalance = IERC20(_asset).balanceOf(targetActor);
        _defaultVars.borrowerCollateralSilo = siloConfig.borrowerCollateralSilo(targetActor);
        _defaultVars.isSolvent = ISilo(silo).isSolvent(targetActor);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _isInterestRateUpdated(address silo) internal view returns (bool) {
        return (defaultVarsBefore[silo].interestRateTimestamp != defaultVarsAfter[silo].interestRateTimestamp)
            && (defaultVarsBefore[silo].interestRateTimestamp == block.timestamp);
    }

    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                  GLOBAL POST CONDITIONS                                   //
    /////////////////////////////////////////////////////////////////////////////////////////////*/

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          BASE                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_BASE_GPOST_A(address silo) internal {
        if (_isInterestRateUpdated(silo)) {
            assertTrue(
                msg.sig == IVaultHandler.deposit.selector || msg.sig == IVaultHandler.mint.selector
                    || msg.sig == IVaultHandler.withdraw.selector || msg.sig == IVaultHandler.redeem.selector
                    || msg.sig == ILiquidationHandler.liquidationCall.selector
                    || msg.sig == ISiloHandler.accrueInterest.selector || msg.sig == IBorrowingHandler.repay.selector
                    || msg.sig == IBorrowingHandler.repayShares.selector,
                BASE_GPOST_A
            );
        }
    }

    function assert_BASE_GPOST_BC(address silo) internal {
        if (defaultVarsBefore[silo].interestRateTimestamp != 0 && _isInterestRateUpdated(silo)) {
            // BASE_GPOST_B
            if (defaultVarsBefore[silo].debtAssets != 0) {
                assertGe(defaultVarsAfter[silo].debtAssets, defaultVarsBefore[silo].debtAssets, BASE_GPOST_B);
            }

            // BASE_GPOST_C
            (uint256 daoFee, uint256 deployerFee,,) = siloConfig.getFeesWithAsset(silo);
            if (daoFee != 0 && deployerFee != 0) {
                assertGe(
                    defaultVarsAfter[silo].daoAndDeployerFees, defaultVarsBefore[silo].daoAndDeployerFees, BASE_GPOST_B
                );
            }
        }
    }

    function assert_BASE_GPOST_D(address silo) internal {
        if (!defaultVarsBefore[silo].isSolvent) {
            if (defaultVarsBefore[silo].borrowerCollateralSilo == defaultVarsAfter[silo].borrowerCollateralSilo) {
                assertFalse(
                    msg.sig == IBorrowingHandler.borrow.selector
                        || msg.sig == IBorrowingHandler.borrowSameAsset.selector
                        || msg.sig == IBorrowingHandler.borrowShares.selector,
                    BASE_GPOST_D
                );
            } else if (
                msg.sig == IBorrowingHandler.borrow.selector || msg.sig == IBorrowingHandler.borrowSameAsset.selector
                    || msg.sig == IBorrowingHandler.borrowShares.selector
            ) {
                assertTrue(defaultVarsAfter[silo].isSolvent, BASE_GPOST_D);
            }
        }

        address borrowerCollateralSilo = siloConfig.borrowerCollateralSilo(targetActor);

        if (!defaultVarsBefore[silo].isSolvent && borrowerCollateralSilo == Actor(payable(targetActor)).lastTarget()) {
            assertFalse(
                msg.sig == IVaultHandler.withdraw.selector || msg.sig == IVaultHandler.redeem.selector, BASE_GPOST_D
            );
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          BORROWING                                        //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_BORROWING_GPOST_C(address silo) internal {
        if ((defaultVarsBefore[silo].isSolvent && !defaultVarsAfter[silo].isSolvent)) {
            assertTrue(false, BORROWING_GPOST_C);
        }
    }
}
