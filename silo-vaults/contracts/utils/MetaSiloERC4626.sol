// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {
ERC4626Upgradeable,
ERC20Upgradeable,
IERC20Upgradeable,
IERC20MetadataUpgradeable
} from "openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

/// @dev MetaSilo is compatible with ERC4626 and all default methods fits here
// TODO what is total supply here? would it be just deposited assets or with earnings??

abstract contract MetaSiloERC4626 is ERC4626Upgradeable {
    // TODO is this needed? if so, only for deposit?
    bool public isEmergency;

    error NotAllowedWhenEmergency();

    /// @dev helper method for when receiver == msg.sender
    function deposit(uint256 _amount) external returns (uint256) {
        return deposit(_amount, msg.sender);
    }

    /// @dev helper method for when receiver == msg.sender
    function mint(uint256 _amount) external returns (uint256) {
        return mint(_amount, msg.sender);
    }

    /// @dev helper method for when receiver == msg.sender
    function withdraw(uint256 _amount) external returns (uint256) {
        return withdraw(_amount, msg.sender, msg.sender);
    }

    /// @dev helper method for when receiver == msg.sender
    function redeem(uint256 _amount) external returns (uint256) {
        return redeem(_amount, msg.sender, msg.sender);
    }

    /// @notice Internal deposit fct used by `deposit()` and `mint()`. Accrues rewards for `caller` and `receiver`.
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares)
        internal
        override
        accrueRewards(caller, receiver)
    {
        if (isEmergency) revert NotAllowedWhenEmergency();

        _beforeDeposit(assets);

        super._deposit(caller, receiver, assets, shares);

        _afterDeposit(assets);
    }

    /// @notice Internal withdraw fct used by `withdraw()` and `redeem()`. Accrues rewards for `caller` and `receiver`.
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
    {
        // if (caller != owner) _approve(owner, msg.sender, allowance(owner, msg.sender) - shares); TODO ??

        // TODO make sure we have enough assets to withdraw
        // TODO can we use _before hook?
        _beforeWithdraw(assets, receiver);

        super._withdraw(caller, receiver, owner, assets, shares);
    }

    /// @notice Internal transfer fct used by `transfer()` and `transferFrom()`. Accrues rewards for `from` and `to`.
    // TODO do we need this? and why this guy burning and minting shares insetead of simply transfering?
    function _transfer(address from, address to, uint256 amount) internal override accrueRewards(from, to) {
        if (from == address(0) || to == address(0)) revert ZeroAddressTransfer(from, to);
        uint256 fromBalance = balanceOf(from);
        if (fromBalance < amount) revert InsufficentBalance();
        _burn(from, amount);
        _mint(to, amount);
        emit Transfer(from, to, amount);
    }

    /// originally this "hooks" should accrueRewards etc but
    /// TODO this is concept version, we need to check if we can simplify all this before/after methods and
    /// use simply before/after transfer SHARES!
    /// unfortunately we do not know asset amount so I think we need to stick with dediated hooks
    /// deposit: _beforeTokenTransfer(0, amount, account)
    /// transfer: _beforeTokenTransfer(not this, amount, not this)
    function _beforeDeposit(address owner, uint256 _amount) internal;

    function _afterDeposit(uint256 _amount) internal;

    function _beforeWithdraw(uint256 _amount) internal returns (uint256 _withdrawn);
}
