// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Address} from "openzeppelin5/utils/Address.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";

import {ISilo} from "../interfaces/ISilo.sol";
import {ISiloRouterImplementation} from "../interfaces/ISiloRouterImplementation.sol";
import {IWrappedNativeToken} from "../interfaces/IWrappedNativeToken.sol";

// solhint-disable ordering

/**
Supporting the following scenarios:

## deposit
- deposit token using SiloRouter.multicall
    SiloRouter.transferFrom(IERC20 _token, address _to, uint256 _amount)
    SiloRouter.approve(IERC20 _token, address _spender, uint256 _amount)
    SiloRouter.deposit(ISilo _silo, uint256 _amount)
- deposit native & wrap in a single tx using SiloRouter.multicall
    SiloRouter.wrap(IWrappedNativeToken _native, uint256 _amount)
    SiloRouter.approve(IERC20 _token, address _spender, uint256 _amount)
    SiloRouter.deposit(ISilo _silo, uint256 _amount)

## borrow
- borrow token Silo.borrow or Silo.borrowSameAsset
    SiloRouter.borrow(ISilo _silo, uint256 _assets, address _receiver)
- borrow same asset Silo.borrowSameAsset
    SiloRouter.borrowSameAsset(ISilo _silo, uint256 _assets, address _receiver)
- borrow wrapped native token and unwrap in a single tx using SiloRouter.multicall
    SiloRouter.borrow(ISilo _silo, uint256 _assets, address _receiver)
    SiloRouter.unwrap(IWrappedNativeToken _native, uint256 _amount)
    SiloRouter.sendValue(address payable _to, uint256 _amount)

## withdraw
- withdraw token using Silo.withdraw
    SiloRouter.withdraw(ISilo _silo, uint256 _amount, address _receiver, ISilo.CollateralType _collateral)
- withdraw wrapped native token and unwrap in a single tx using SiloRouter.multicall
    SiloRouter.withdraw(ISilo _silo, uint256 _amount, address _receiver, ISilo.CollateralType _collateral)
    SiloRouter.unwrap(IWrappedNativeToken _native, uint256 _amount)
    SiloRouter.sendValue(address payable _to, uint256 _amount)
- full withdraw token using Silo.redeem
    SiloRouter.withdrawAll(ISilo _silo, address _receiver, ISilo.CollateralType _collateral)
- full withdraw wrapped native token and unwrap in a single tx using SiloRouter.multicall
    SiloRouter.withdrawAll(ISilo _silo, address _receiver, ISilo.CollateralType _collateral)
    SiloRouter.unwrapAll(IWrappedNativeToken _native)
    SiloRouter.sendValueAll(address payable _to)

## repay
- repay token using SiloRouter.multicall
    SiloRouter.transferFrom(IERC20 _token, address _to, uint256 _amount)
    SiloRouter.approve(IERC20 _token, address _spender, uint256 _amount)
    SiloRouter.repay(ISilo _silo, uint256 _assets, address _borrower)
- repay native & wrap in a single tx using SiloRouter.multicall
    SiloRouter.wrap(IWrappedNativeToken _native, uint256 _amount)
    SiloRouter.approve(IERC20 _token, address _spender, uint256 _amount)
    SiloRouter.repay(ISilo _silo, uint256 _assets, address _borrower)
- full repay token using SiloRouter.multicall
    SiloRouter.repayAll(ISilo _silo, address _borrower)
    SiloRouter.sendValueAll(address payable _to)
 */

/// @dev This contract should never use `msg.value` as `SiloRouter` contract executes multicall with a delegatecall.
/// @dev This contract should not work with storage. If needed, update SiloRouter accordingly.
/// @dev Caller should ensure that the router balance is empty after multicall.
contract SiloRouterImplementation is ISiloRouterImplementation {
    using SafeERC20 for IERC20;

    /// @inheritdoc ISiloRouterImplementation
    function wrap(IWrappedNativeToken _native, uint256 _amount) public payable virtual {
        _native.deposit{value: _amount}();
    }

    /// @inheritdoc ISiloRouterImplementation
    function unwrap(IWrappedNativeToken _native, uint256 _amount) public payable virtual {
        _native.withdraw(_amount);
    }

    /// @inheritdoc ISiloRouterImplementation
    function unwrapAll(IWrappedNativeToken _native) external payable virtual {
        uint256 balance = _native.balanceOf(address(this));
        unwrap(_native, balance);
    }

    /// @inheritdoc ISiloRouterImplementation
    function sendValue(address payable _to, uint256 _amount) public payable virtual {
        Address.sendValue(_to, _amount);
    }

    /// @inheritdoc ISiloRouterImplementation
    function sendValueAll(address payable _to) external payable virtual {
        uint256 balance = address(this).balance;

        if (balance != 0) { // expect this fn to be used as a sanity check at the end of the multicall
            sendValue(_to, balance);
        }
    }

    /// @inheritdoc ISiloRouterImplementation
    function transfer(IERC20 _token, address _to, uint256 _amount) public payable virtual {
        _token.safeTransfer(_to, _amount);
    }

    /// @inheritdoc ISiloRouterImplementation
    function transferAll(IERC20 _token, address _to) external payable virtual {
        uint256 balance = _token.balanceOf(address(this));

        if (balance != 0) { // expect this fn to be used as a sanity check at the end of the multicall
            transfer(_token, _to, balance);
        }
    }

    /// @inheritdoc ISiloRouterImplementation
    function transferFrom(IERC20 _token, address _to, uint256 _amount) public payable virtual {
        _token.safeTransferFrom(msg.sender, _to, _amount);
    }

    /// @inheritdoc ISiloRouterImplementation
    function approve(IERC20 _token, address _spender, uint256 _amount) public payable virtual {
        _token.forceApprove(_spender, _amount);
    }

    /// @inheritdoc ISiloRouterImplementation
    function deposit(
        ISilo _silo,
        uint256 _amount,
        ISilo.CollateralType _collateral
    ) external payable virtual returns (uint256 shares) {
        shares = _silo.deposit(_amount, msg.sender, _collateral);
    }

    /// @inheritdoc ISiloRouterImplementation
    function withdraw(
        ISilo _silo,
        uint256 _amount,
        address _receiver,
        ISilo.CollateralType _collateral
    ) external payable virtual returns (uint256 assets) {
        assets = _silo.withdraw(_amount, _receiver, msg.sender, _collateral);
    }

    /// @inheritdoc ISiloRouterImplementation
    function withdrawAll(
        ISilo _silo,
        address _receiver,
        ISilo.CollateralType _collateral
    ) external payable virtual returns (uint256 assets) {
        uint256 sharesAmount = _silo.maxRedeem(msg.sender, _collateral);
        assets = _silo.redeem(sharesAmount, _receiver, msg.sender, _collateral);
    }

    /// @inheritdoc ISiloRouterImplementation
    function borrow(
        ISilo _silo,
        uint256 _assets,
        address _receiver
    ) external payable virtual returns (uint256 shares) {
        shares = _silo.borrow(_assets, _receiver, msg.sender);
    }

    /// @inheritdoc ISiloRouterImplementation
    function borrowSameAsset(
        ISilo _silo,
        uint256 _assets,
        address _receiver
    ) external payable virtual returns (uint256 shares) {
        shares = _silo.borrowSameAsset(_assets, _receiver, msg.sender);
    }

    /// @inheritdoc ISiloRouterImplementation
    function repay(ISilo _silo, uint256 _assets) public payable virtual returns (uint256 shares) {
        shares = _silo.repay(_assets, msg.sender);
    }

    /// @inheritdoc ISiloRouterImplementation
    function repayAll(ISilo _silo) external payable virtual returns (uint256 shares) {
        uint256 repayAmount = _silo.maxRepay(msg.sender);
        IERC20 asset = IERC20(_silo.asset());

        transferFrom(asset, address(this), repayAmount);
        approve(asset, address(_silo), repayAmount);

        shares = repay(_silo, repayAmount);
    }

    /// @inheritdoc ISiloRouterImplementation
    function repayAllNative(
        IWrappedNativeToken _native,
        ISilo _silo
    ) external payable virtual returns (uint256 shares) {
        uint256 repayAmount = _silo.maxRepay(msg.sender);

        wrap(_native, repayAmount);
        approve(IERC20(address(_native)), address(_silo), repayAmount);

        shares = repay(_silo, repayAmount);
    }
}
