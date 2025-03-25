// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries

// Interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Contracts
import {HandlerAggregator} from "../HandlerAggregator.t.sol";

import "forge-std/console.sol";

/// @title ERC4626Invariants
/// @notice Implements Invariants for the protocol
/// @dev Inherits HandlerAggregator to check actions in assertion testing mode
abstract contract ERC4626Invariants is HandlerAggregator {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           ASSET                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_ERC4626_ASSETS_INVARIANT_A() internal {
        try vault.asset() {}
        catch {
            fail(ERC4626_ASSETS_INVARIANT_A);
        }
    }

    function assert_ERC4626_ASSETS_INVARIANT_B() internal {
        try vault.totalAssets() returns (uint256 totalAssets) {
            totalAssets;
        } catch {
            fail(ERC4626_ASSETS_INVARIANT_B);
        }
    }

    function assert_ERC4626_ASSETS_INVARIANT_C() internal {
        uint256 _assets = _getRandomValue(_maxAssets());
        uint256 shares;
        bool notFirstLoop;

        for (uint256 i; i < NUMBER_OF_ACTORS; i++) {
            vm.prank(actorAddresses[i]);
            uint256 tempShares = vault.convertToShares(_assets);

            // Compare the shares with the previous iteration expect the first one
            if (notFirstLoop) {
                assertEq(shares, tempShares, ERC4626_ASSETS_INVARIANT_C);
            } else {
                shares = tempShares;
                notFirstLoop = true;
            }
        }
    }

    function assert_ERC4626_ASSETS_INVARIANT_D() internal {
        uint256 _shares = _getRandomValue(_maxShares());
        uint256 assets;
        bool notFirstLoop;

        for (uint256 i; i < NUMBER_OF_ACTORS; i++) {
            vm.prank(actorAddresses[i]);
            uint256 tempAssets = vault.convertToAssets(_shares);

            // Compare the shares with the previous iteration expect the first one
            if (notFirstLoop) {
                assertEq(assets, tempAssets, ERC4626_ASSETS_INVARIANT_D);
            } else {
                assets = tempAssets;
                notFirstLoop = true;
            }
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     ACTIONS: DEPOSIT                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_ERC4626_DEPOSIT_INVARIANT_A(address _account) internal {
        try vault.maxDeposit(_account) {}
        catch {
            fail(ERC4626_DEPOSIT_INVARIANT_A);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      ACTIONS: MINT                                        //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_ERC4626_MINT_INVARIANT_A(address _account) internal {
        try vault.maxMint(_account) {}
        catch {
            fail(ERC4626_MINT_INVARIANT_A);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    ACTIONS: WITHDRAW                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_ERC4626_WITHDRAW_INVARIANT_A(address _account) internal {
        try vault.maxWithdraw(_account) {}
        catch {
            fail(ERC4626_WITHDRAW_INVARIANT_A);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    ACTIONS: REDEEM                                        //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_ERC4626_REDEEM_INVARIANT_A(address _account) internal {
        try vault.maxRedeem(_account) {}
        catch {
            fail(ERC4626_REDEEM_INVARIANT_A);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         UTILS                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _maxShares() internal view returns (uint256 shares) {
        shares = vault.totalSupply();
        shares = shares == 0 ? 1 : shares;
    }

    function _maxAssets() internal view returns (uint256 assets) {
        assets = vault.totalAssets();
        assets = assets == 0 ? 1 : assets;
    }

    function _max_withdraw(address from) internal view virtual returns (uint256) {
        return vault.convertToAssets(vault.balanceOf(from)); // may be different from
            // maxWithdraw(from)
    }

    function _max_redeem(address from) internal view virtual returns (uint256) {
        return vault.balanceOf(from); // may be different from maxRedeem(from)
    }
}
