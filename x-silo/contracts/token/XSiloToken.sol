// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {ERC4626, ERC20, IERC20} from "openzeppelin5/token/ERC20/extensions/ERC4626.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";

import {TokenHelper} from "silo-core/contracts/lib/TokenHelper.sol";

import {XRedeemPolicy} from "./XRedeemPolicy.sol";
import {Stream} from "../Stream.sol";


contract XSiloToken is ERC4626, XRedeemPolicy {
    Stream public immutable STREAM;

    constructor(address _asset, Stream _stream)
        Ownable(msg.sender)
        ERC4626(IERC20(_asset))
        ERC20(string.concat('x', TokenHelper.symbol(_asset)), string.concat('x', TokenHelper.symbol(_asset)))
    {
        STREAM = _stream;
    }

    function convertToShares(uint256 _value) public view virtual override(ERC4626, XRedeemPolicy) returns (uint256) {
        return ERC4626.convertToShares(_value);
    }

    function convertToAssets(uint256 _value) public view virtual override(ERC4626, XRedeemPolicy) returns (uint256) {
        return ERC4626.convertToAssets(_value);
    }

    /** @dev See {IERC4626-maxWithdraw}. */
    function maxWithdraw(address owner) public view virtual override returns (uint256) {
        return convertToAssets(maxRedeem(owner));
    }

    /** @dev See {IERC4626-maxRedeem}. */
    function maxRedeem(address owner) public view virtual override returns (uint256 shares) {
        uint256 shares = balanceOf(owner);

        uint256 len = userRedeems[owner].length;

        if (len == 0) shares = getAmountByVestingDuration(shares, 0);
        else {
            for (uint256 i = 0; i < len; i++) {
                RedeemInfo storage _redeem = userRedeems[owner][i];
                shares += (_redeem.endTime <= block.timestamp ? _redeem.siloAmount : 0);
            }
        }
    }

    /** @dev See {IERC4626-previewWithdraw}. */
    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Ceil);
    }

    /** @dev See {IERC4626-previewRedeem}. */
    function previewRedeem(uint256 shares) public view virtual returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    // TODO previewWithdraw and previewRedeem probably need to stay as is, because
    // they are not based on address, just raw amounts
    // >> getAmountByVestingDuration(amount, 0)

    /** @dev See {IERC4626-withdraw}. */
    function withdraw(uint256 assets, address receiver, address owner) public virtual override returns (uint256) {
        /* TODO
        we can go over queue first, to withdraw tokens that are after period
        should we sort queue? if we want to give most optimal solution we have to sort
        if not - user can waste money for no reason
        we can sort when we adding to queue, unfortunately this will mess with indexes

        once we done with queue and we still need assets we can do immediate redeem for the missing part

        */
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }

        uint256 shares = previewWithdraw(assets);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    /** @dev See {IERC4626-redeem}. */
    function redeem(uint256 shares, address receiver, address owner) public virtual override(ERC4626, XRedeemPolicy) returns (uint256) {
        /*
        TODO
        same issue as for withdraw
        */
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }

        uint256 assets = previewRedeem(shares);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return assets;
    }

    /**
     * @dev Withdraw/redeem common workflow.
     */
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        // If _asset is ERC-777, `transfer` can trigger a reentrancy AFTER the transfer happens through the
        // `tokensReceived` hook. On the other hand, the `tokensToSend` hook, that is triggered before the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer after the burn so that any reentrancy would happen after the
        // shares are burned and after the assets are transferred, which is a valid state.
        _burn(owner, shares);
        SafeERC20.safeTransfer(IERC20(asset()), receiver, assets);

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    /// @notice This would make the amount that the user would need to "gift" the market in order to significantly
    /// inflate the share price very large and impractical.
    function _decimalsOffset() internal view virtual override returns (uint8) {
        return 6;
    }

    function _burnShares(address _owner, uint256 _shares) internal virtual override {
        return ERC20._burn(_owner, _shares);
    }

    function _transferShares(address _from, address _to, uint256 _value) internal virtual override {
        return ERC20._transfer(_from, _to, _value);
    }

    function _update(address _from, address _to, uint256 _value) internal virtual override {
        STREAM.claimRewards();

        super._update(_from, _to, _value);

        if (_value == 0) return;

        // TODO notification
        // _afterTokenTransfer(_from, _to, _value);
    }
}