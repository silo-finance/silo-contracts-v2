// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {Actor} from "../../utils/Actor.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";

/// @title ERC4626PostconditionsHandler
/// @notice Handler test contract for a set of predefinet postconditions
abstract contract ERC4626PostconditionsHandler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   PROPERTIES: NON-REVERT                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_ERC4626_DEPOSIT_INVARIANT_C() external setup {
        address _account = address(actor);
        uint256 maxDeposit = vault.maxDeposit(_account);
        uint256 accountBalance = asset.balanceOf(_account);

        if (accountBalance < maxDeposit) {
            asset.mint(_account, maxDeposit - asset.balanceOf(_account));
        }

        if (maxDeposit != 0) {
            vm.prank(_account);
            try vault.deposit(maxDeposit, _account) returns (uint256 shares) {
                /// @dev restore original state to not break invariants
                vm.prank(_account);
                vault.redeem(shares, address(0), _account);
            } catch {
                assertTrue(false, ERC4626_DEPOSIT_INVARIANT_C);
            }
        }
    }

    function assert_ERC4626_MINT_INVARIANT_C() public setup {
        address _account = address(actor);
        uint256 maxMint = vault.maxMint(_account);
        uint256 accountBalance = asset.balanceOf(_account);

        uint256 maxMintToAssets = vault.convertToAssets(maxMint);

        if (accountBalance < maxMintToAssets) {
            asset.mint(_account, maxMintToAssets - asset.balanceOf(_account));
        }

        if (maxMint != 0) {
            vm.prank(_account);
            try vault.mint(maxMint, _account) {
                /// @dev restore original state to not break invariants
                vm.prank(_account);
                vault.redeem(maxMint, address(0), _account);
            } catch {
                assertTrue(false, ERC4626_MINT_INVARIANT_C);
            }
        }
    }

    function assert_ERC4626_WITHDRAW_INVARIANT_C() public setup {
        address _account = address(actor);
        uint256 maxWithdraw = vault.maxWithdraw(_account);

        if (maxWithdraw != 0) {
            vm.prank(_account);
            try vault.withdraw(maxWithdraw, _account, _account) {}
            catch {
                assertTrue(false, ERC4626_WITHDRAW_INVARIANT_C);
            }
        }
    }

    function assert_ERC4626_REDEEM_INVARIANT_C() public setup {
        address _account = address(actor);
        uint256 maxRedeem = vault.maxRedeem(_account);

        if (maxRedeem != 0) {
            vm.prank(_account);
            try vault.redeem(maxRedeem, _account, _account) {}
            catch {
                assertTrue(false, ERC4626_REDEEM_INVARIANT_C); //test_replay_assert_ERC4626_REDEEM_INVARIANT_C
            }
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   PROPERTIES: ROUNDTRIP                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_ERC4626_ROUNDTRIP_INVARIANT_A(uint256 _assets) external {
        _mintAndApprove(address(vault.asset()), address(this), address(vault), _assets);

        uint256 shares = vault.deposit(_assets, address(this));

        uint256 redeemedAssets = vault.redeem(shares, address(this), address(this));

        assertLe(redeemedAssets, _assets, ERC4626_ROUNDTRIP_INVARIANT_A);
    }

    function assert_ERC4626_ROUNDTRIP_INVARIANT_B(uint256 _assets) external {
        _mintAndApprove(address(vault.asset()), address(this), address(vault), _assets);

        uint256 shares = vault.deposit(_assets, address(this));

        uint256 withdrawnShares = vault.withdraw(_assets, address(this), address(this));

        /// @dev restore original state to not break invariants
        vault.redeem(vault.balanceOf(address(this)), address(this), address(this));

        assertGe(withdrawnShares, shares, ERC4626_ROUNDTRIP_INVARIANT_B);
    }

    function assert_ERC4626_ROUNDTRIP_INVARIANT_C(uint256 _shares) external {
        _mintApproveAndMint(address(vault), address(this), _shares);

        uint256 redeemedAssets = vault.redeem(_shares, address(this), address(this));

        uint256 mintedShares = vault.deposit(redeemedAssets, address(this));

        /// @dev restore original state to not break invariants
        vault.redeem(mintedShares, address(this), address(this));

        assertLe(mintedShares, _shares, ERC4626_ROUNDTRIP_INVARIANT_C);
    }

    function assert_ERC4626_ROUNDTRIP_INVARIANT_D(uint256 _shares) external {
        _mintApproveAndMint(address(vault), address(this), _shares);

        uint256 redeemedAssets = vault.redeem(_shares, address(this), address(this));

        uint256 depositedAssets = vault.mint(_shares, address(this));

        /// @dev restore original state to not break invariants
        vault.withdraw(depositedAssets, address(this), address(this));

        assertGe(depositedAssets, redeemedAssets, ERC4626_ROUNDTRIP_INVARIANT_D);
    }

    function assert_ERC4626_ROUNDTRIP_INVARIANT_E(uint256 _shares) external {
        _mintAndApprove(address(vault.asset()), address(this), address(vault), vault.convertToAssets(_shares));

        uint256 depositedAssets = vault.mint(_shares, address(this));

        uint256 withdrawnShares = vault.withdraw(depositedAssets, address(this), address(this));

        /// @dev restore original state to not break invariants
        vault.redeem(vault.balanceOf(address(this)), address(this), address(this));

        assertGe(withdrawnShares, _shares, ERC4626_ROUNDTRIP_INVARIANT_E);
    }

    function assert_ERC4626_ROUNDTRIP_INVARIANT_F(uint256 _shares) external {
        _mintAndApprove(address(vault.asset()), address(this), address(vault), vault.convertToAssets(_shares));

        uint256 depositedAssets = vault.mint(_shares, address(this));

        uint256 redeemedAssets = vault.redeem(_shares, address(this), address(this));

        assertLe(redeemedAssets, depositedAssets, ERC4626_ROUNDTRIP_INVARIANT_F);
    }

    function assert_ERC4626_ROUNDTRIP_INVARIANT_G(uint256 _assets) external {
        _mintApproveAndDeposit(address(vault), address(this), _assets);

        uint256 redeemedShares = vault.withdraw(_assets, address(this), address(this));

        uint256 depositedAssets = vault.mint(redeemedShares, address(this));

        /// @dev restore original state to not break invariants
        vault.redeem(vault.balanceOf(address(this)), address(this), address(this));

        assertGe(depositedAssets, _assets, ERC4626_ROUNDTRIP_INVARIANT_G);
    }

    function assert_ERC4626_ROUNDTRIP_INVARIANT_H(uint256 _assets) external {
        _mintApproveAndDeposit(address(vault), address(this), _assets);

        uint256 redeemedShares = vault.withdraw(_assets, address(this), address(this));

        uint256 mintedShares = vault.deposit(_assets, address(this));

        /// @dev restore original state to not break invariants
        vault.redeem(vault.balanceOf(address(this)), address(this), address(this));

        assertLe(mintedShares, redeemedShares, ERC4626_ROUNDTRIP_INVARIANT_H)
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                  PROPERTIES: ACCOUNTING                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_INV_ACCOUNTING_B(uint256 amount) external { // TODO check this property
            //assertEq(vault.convertToShares(vault.convertToAssets(amount)), amount, INV_ACCOUNTING_B);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
