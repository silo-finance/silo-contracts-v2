// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {ERC4626, ERC20, IERC20} from "openzeppelin5/token/ERC20/extensions/ERC4626.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";

import {TokenHelper} from "silo-core/contracts/lib/TokenHelper.sol";
import {TransientReentrancy} from "silo-core/contracts/hooks/_common/TransientReentrancy.sol";

import {XRedeemPolicy} from "./XRedeemPolicy.sol";
import {Stream} from "../Stream.sol";


// TODO do we need nonReentrant on vault methods? if so we need to override them all

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
    function maxWithdraw(address _owner) public view virtual override returns (uint256 assets) {
        uint256 xSiloAfterVesting = getXAmountByVestingDuration(balanceOf(_owner), 0);
        assets = convertToAssets(xSiloAfterVesting);
    }

    /** @dev See {IERC4626-previewWithdraw}. */
    function previewWithdraw(uint256 _assets) public view virtual override returns (uint256 shares) {
        uint256 _xSiloAfterVesting = convertToShares(_assets);
        shares = getAmountInByVestingDuration(_xSiloAfterVesting, 0);
    }

    /** @dev See {IERC4626-previewRedeem}. */
    function previewRedeem(uint256 _shares) public view virtual override returns (uint256 assets) {
        assets = getXAmountByVestingDuration(_shares, 0);
    }

    // TODO withdraw/reddeem isees preview, we override preview so it should work out of the box - QA!

    /// @notice This would make the amount that the user would need to "gift" the market in order to significantly
    /// inflate the share price very large and impractical.
    function _decimalsOffset() internal view virtual override returns (uint8) {
        return 6;
    }

    function _burnShares(address _owner, uint256 _shares) internal virtual override {
        return ERC20._burn(_owner, _shares);
    }

    function _mintShares(address _account, uint256 _value) internal virtual override {
        return ERC20._mint(_account, _value);
    }

    function _withdraw(
        address _caller,
        address _receiver,
        address _owner,
        uint256 _assetsToTransfer,
        uint256 _sharesToBurn
    ) internal virtual override(ERC4626, XRedeemPolicy) {
        ERC4626._withdraw(_caller, _receiver, _owner, _assetsToTransfer, _sharesToBurn);
    }

    function _update(address _from, address _to, uint256 _value) internal virtual override {
        STREAM.claimRewards();

        super._update(_from, _to, _value);

        if (_value == 0) return;

        // TODO notification
        // _afterTokenTransfer(_from, _to, _value);
    }
}