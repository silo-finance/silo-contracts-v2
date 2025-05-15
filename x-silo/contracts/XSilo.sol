// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC4626, IERC4626, ERC20, IERC20} from "openzeppelin5/token/ERC20/extensions/ERC4626.sol";

import {TokenHelper} from "silo-core/contracts/lib/TokenHelper.sol";

import {XSiloManagement, INotificationReceiver} from "./modules/XSiloManagement.sol";
import {XRedeemPolicy} from "./modules/XRedeemPolicy.sol";
import {Stream} from "./modules/Stream.sol";

contract XSilo is XSiloManagement, ERC4626, XRedeemPolicy {
    error ZeroShares();
    error ZeroAssets();
    error SelfTransferNotAllowed();

    constructor(address _initialOwner, address _asset, address _stream)
        XSiloManagement(_initialOwner, _stream)
        ERC4626(IERC20(_asset))
        ERC20(string.concat("x", TokenHelper.symbol(_asset)), string.concat("x", TokenHelper.symbol(_asset)))
    {
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 _assets, address _receiver) public virtual override nonReentrant returns (uint256 shares) {
        shares = super.deposit(_assets, _receiver);
    }

    /// @inheritdoc IERC4626
    function mint(uint256 _shares, address _receiver) public virtual override nonReentrant returns (uint256 assets) {
        assets = super.mint(_shares, _receiver);
    }

    /// @inheritdoc IERC4626
    /// @notice `withdraw` uses a duration of 0 to calculate amount of Silo to withdraw. Duration 0 represents
    /// the worst-case scenario for asset withdrawals. To obtain a better deal, please use the custom method
    /// `redeemSilo` with different duration.
    function withdraw(uint256 _assets, address _receiver, address _owner)
        public
        virtual
        override
        nonReentrant
        returns (uint256 shares)
    {
        shares = super.withdraw(_assets, _receiver, _owner);
    }

    /// @inheritdoc IERC4626
    /// @notice `redeem` uses a duration of 0 to calculate amount of Silo to redeem. Duration 0 represents
    /// the worst-case scenario for asset withdrawals. To obtain a better deal, please use the custom method
    /// `redeemSilo` with different duration.
    function redeem(uint256 _shares, address _receiver, address _owner)
        public
        virtual
        override
        nonReentrant
        returns (uint256 assets)
    {
        assets = super.redeem(_shares, _receiver, _owner);
    }

    /// @inheritdoc ERC20
    function transfer(address _to, uint256 _value) public virtual override(ERC20, IERC20) nonReentrant returns (bool) {
        return super.transfer(_to, _value);
    }

    /// @inheritdoc ERC20
    function transferFrom(address _from, address _to, uint256 _value)
        public
        virtual
        override(ERC20, IERC20)
        nonReentrant
        returns (bool)
    {
        return super.transferFrom(_from, _to, _value);
    }

    // TODO withdraw/redeem uses preview, we override preview so it should work out of the box - QA!

    /// @inheritdoc IERC4626
    function totalAssets() public view virtual override returns (uint256 total) {
        total = super.totalAssets();

        Stream stream_ = stream;
        if (address(stream_) != address(0)) total += stream_.pendingRewards();
    }

    /// @inheritdoc IERC4626
    function convertToShares(uint256 _assets) public view virtual override(ERC4626, XRedeemPolicy) returns (uint256) {
        return ERC4626.convertToShares(_assets);
    }

    /// @inheritdoc IERC4626
    function convertToAssets(uint256 _shares) public view virtual override(ERC4626, XRedeemPolicy) returns (uint256) {
        return ERC4626.convertToAssets(_shares);
    }

    /// @inheritdoc IERC4626
    /// @notice `maxWithdraw` uses a duration of 0 to calculate the result, which represents the worst-case scenario
    /// for asset withdrawals. To obtain a better deal, please use the custom method `getAmountByVestingDuration` with
    /// different duration.
    function maxWithdraw(address _owner) public view virtual override returns (uint256 assets) {
        uint256 xSiloAfterVesting = getXAmountByVestingDuration(balanceOf(_owner), 0);
        assets = convertToAssets(xSiloAfterVesting);
    }

    /// @inheritdoc IERC4626
    /// @notice `previewWithdraw` uses a duration of 0 to calculate the result, which represents the worst-case scenario
    /// for asset withdrawals. To obtain a better deal, please use the custom method `getAmountByVestingDuration` with
    /// different duration.
    function previewWithdraw(uint256 _assets) public view virtual override returns (uint256 shares) {
        uint256 _xSiloAfterVesting = convertToShares(_assets);
        shares = getAmountInByVestingDuration(_xSiloAfterVesting, 0);
    }

    /// @inheritdoc IERC4626
    /// @notice `previewRedeem` uses a duration of 0 to calculate the result, which represents the worst-case scenario
    /// for asset redeem. To obtain a better deal, please use the custom method `getAmountByVestingDuration` with
    /// different duration.
    function previewRedeem(uint256 _shares) public view virtual override returns (uint256 assets) {
        uint256 xSiloAfterVesting = getXAmountByVestingDuration(_shares, 0);
        assets = convertToAssets(xSiloAfterVesting);
    }

    /**
     * @dev Deposit/mint common workflow.
     */
    function _deposit(address _caller, address _receiver, uint256 _assets, uint256 _shares) internal virtual override {
        require(_shares != 0, ZeroShares());
        require(_assets != 0, ZeroAssets());

        super._deposit(_caller, _receiver, _assets, _shares);
    }

    function _withdraw(
        address _caller,
        address _receiver,
        address _owner,
        uint256 _assetsToTransfer,
        uint256 _sharesToBurn
    ) internal virtual override(ERC4626, XRedeemPolicy) {
        require(_sharesToBurn != 0, ZeroShares());
        require(_assetsToTransfer != 0, ZeroAssets());

        ERC4626._withdraw(_caller, _receiver, _owner, _assetsToTransfer, _sharesToBurn);
    }

    function _transferShares(address _from, address _to, uint256 _shares) internal virtual override {
        return ERC20._transfer(_from, _to, _shares);
    }

    function _burnShares(address _account, uint256 _shares) internal virtual override {
        return ERC20._burn(_account, _shares);
    }

    function _update(address _from, address _to, uint256 _value) internal virtual override {
        require(_from != _to, SelfTransferNotAllowed());

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
