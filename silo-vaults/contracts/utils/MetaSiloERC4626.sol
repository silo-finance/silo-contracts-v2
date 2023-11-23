// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {
ERC4626Upgradeable,
ERC20Upgradeable,
IERC20Upgradeable,
IERC20MetadataUpgradeable
} from "openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

/// @dev MetaSilo is compatible with ERC4626 and all default methods fits here
///
abstract contract MetaSiloERC4626 is ERC4626Upgradeable {
    function deposit(uint256 _amount) external returns (uint256) {
        return deposit(_amount, msg.sender);
    }

    function mint(uint256 _amount) external returns (uint256) {
        return mint(_amount, msg.sender);
    }

    function withdraw(uint256 _amount) external returns (uint256) {
        return withdraw(_amount, msg.sender, msg.sender);
    }

    function redeem(uint256 _amount) external returns (uint256) {
        return redeem(_amount, msg.sender, msg.sender);
    }

    /// @notice Internal deposit fct used by `deposit()` and `mint()`. Accrues rewards for `caller` and `receiver`.
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares)
        internal
        override
        accrueRewards(caller, receiver)
    {
        if (isEmergency) revert DepositNotAllowedEmergency();
        IERC20(asset()).safeTransferFrom(caller, address(this), assets);
        _mint(receiver, shares);
        emit Deposit(caller, receiver, assets, shares);
        _afterDeposit(assets);
    }

    /// @notice Internal withdraw fct used by `withdraw()` and `redeem()`. Accrues rewards for `caller` and `receiver`.
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
        accrueRewards(owner, receiver)
    {
        if (caller != owner) _approve(owner, msg.sender, allowance(owner, msg.sender) - shares);
        _burn(owner, shares);
        emit Withdraw(caller, receiver, owner, assets, shares);
        _beforeWithdraw(assets, receiver);
        IERC20(asset()).safeTransfer(receiver, assets);
    }

    /// @notice Internal transfer fct used by `transfer()` and `transferFrom()`. Accrues rewards for `from` and `to`.
    function _transfer(address from, address to, uint256 amount) internal override accrueRewards(from, to) {
        if (from == address(0) || to == address(0)) revert ZeroAddressTransfer(from, to);
        uint256 fromBalance = balanceOf(from);
        if (fromBalance < amount) revert InsufficentBalance();
        _burn(from, amount);
        _mint(to, amount);
        emit Transfer(from, to, amount);
    }
}
