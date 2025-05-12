// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC4626, ERC20, IERC20} from "openzeppelin5/token/ERC20/extensions/ERC4626.sol";

import {TokenHelper} from "silo-core/contracts/lib/TokenHelper.sol";

import {XSiloManagement, INotificationReceiver} from "./XSiloManagement.sol";
import {XRedeemPolicy} from "./XRedeemPolicy.sol";
import {Stream} from "./Stream.sol";

contract XSilo is XSiloManagement, ERC4626, XRedeemPolicy {
    constructor(address _asset)
        ERC4626(IERC20(_asset))
        ERC20(string.concat('x', TokenHelper.symbol(_asset)), string.concat('x', TokenHelper.symbol(_asset)))
    {
    }

    /** @dev See {IERC4626-totalAssets}. */
    function totalAssets() public view virtual override returns (uint256 total) {
        total = super.totalAssets();

        Stream stream_ = stream;
        if (address(stream_) != address(0)) total += stream_.pendingRewards();
    }

    /** @dev See {IERC4626-convertToShares}. */
    function convertToShares(uint256 _assets) public view virtual override(ERC4626, XRedeemPolicy) returns (uint256) {
        return ERC4626.convertToShares(_assets);
    }

    /** @dev See {IERC4626-convertToAssets}. */
    function convertToAssets(uint256 _shares) public view virtual override(ERC4626, XRedeemPolicy) returns (uint256) {
        return ERC4626.convertToAssets(_shares);
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
        uint256 xSiloAfterVesting = getXAmountByVestingDuration(_shares, 0);
        assets = convertToAssets(xSiloAfterVesting);
    }

    /** @dev See {IERC4626-deposit}. */
    function deposit(uint256 _assets, address _receiver) public virtual override nonReentrant returns (uint256) {
        return super.deposit(_assets, _receiver);
    }

    /** @dev See {IERC4626-mint}. */
    function mint(uint256 _shares, address _receiver) public virtual override nonReentrant returns (uint256) {
        return super.mint(_shares, _receiver);
    }

    /** @dev See {IERC4626-withdraw}. */
    function withdraw(uint256 _assets, address _receiver, address _owner)
        public
        virtual
        override
        nonReentrant
        returns (uint256)
    {
        return super.withdraw(_assets, _receiver, _owner);
    }

    /** @dev See {IERC4626-redeem}. */
    function redeem(uint256 _shares, address _receiver, address _owner)
        public
        virtual
        override
        nonReentrant
        returns (uint256)
    {
        return super.redeem(_shares, _receiver, _owner);
    }

    // TODO withdraw/reddeem uses preview, we override preview so it should work out of the box - QA!

    function _withdraw(
        address _caller,
        address _receiver,
        address _owner,
        uint256 _assetsToTransfer,
        uint256 _sharesToBurn
    ) internal virtual override(ERC4626, XRedeemPolicy) {
        ERC4626._withdraw(_caller, _receiver, _owner, _assetsToTransfer, _sharesToBurn);
    }

    function _transferShares(address _from, address _owner, uint256 _shares) internal virtual override {
        return ERC20._transfer(_from, _owner, _shares);
    }

    function _burnShares(address _account, uint256 _shares) internal virtual override {
        return ERC20._burn(_account, _shares);
    }

    function _update(address _from, address _to, uint256 _value) internal virtual override {
        Stream stream_ = stream;
        if (address(stream_) != address(0)) stream_.claimRewards();

        super._update(_from, _to, _value);

        INotificationReceiver receiver = notificationReceiver;

        if (_value == 0 || address(receiver) == address(0)) return;

        receiver.afterTokenTransfer({
            _sender: _from,
            _senderBalance: balanceOf(_from),
            _recipient: _to,
            _recipientBalance: balanceOf(_to),
            _totalSupply: totalSupply(),
            _amount: _value
        });
    }
}