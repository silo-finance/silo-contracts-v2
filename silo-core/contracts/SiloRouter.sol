// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Address} from "openzeppelin5/utils/Address.sol";

import {Pausable} from "openzeppelin5/utils/Pausable.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {Multicall} from "openzeppelin5/utils/Multicall.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {ISilo} from "./interfaces/ISilo.sol";
import {ISiloRouter} from "./interfaces/ISiloRouter.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IWrappedNativeToken} from "./interfaces/IWrappedNativeToken.sol";

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
- borrow token using Silo.borrow or Silo.borrowSameAsset
    SiloRouter.borrow(ISilo _silo, uint256 _assets, address _receiver)
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
    SiloRouter.unwrap(IWrappedNativeToken _native, uint256 _amount)
    SiloRouter.sendValue(address payable _to, uint256 _amount)

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
 */

/// @title SiloRouter
/// @notice Silo Router is a utility contract that aims to improve UX. It can batch any number or combination
/// of actions (Deposit, Withdraw, Borrow, Repay) and execute them in a single transaction.
/// @dev SiloRouter requires only first action asset to be approved
/// @custom:security-contact security@silo.finance
contract SiloRouter is Pausable, Ownable2Step, ISiloRouter {
    using SafeERC20 for IERC20;

    constructor (address _initialOwner) Ownable(_initialOwner) {}

    /// @dev needed for unwrapping native tokens
    receive() external payable {
        // `execute` method calls `IWrappedNativeToken.withdraw()`
        // and we need to receive the withdrawn native token unconditionally
    }

    /// @inheritdoc ISiloRouter
    function multicall(bytes[] calldata data) external virtual payable returns (bytes[] memory results) {
        bytes memory context = msg.sender == _msgSender()
            ? new bytes(0)
            : msg.data[msg.data.length - _contextSuffixLength():];

        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            results[i] = Address.functionDelegateCall(address(this), bytes.concat(data[i], context));
        }

        return results;
    }

    /// @inheritdoc ISiloRouter
    function pause() external virtual onlyOwner {
        _pause();
    }

    /// @inheritdoc ISiloRouter
    function unpause() external virtual onlyOwner {
        _unpause();
    }

    /// @inheritdoc ISiloRouter
    function wrap(IWrappedNativeToken _native, uint256 _amount) external payable virtual whenNotPaused {
        IWrappedNativeToken(_native).deposit{value: _amount}();
    }

    /// @inheritdoc ISiloRouter
    function unwrap(IWrappedNativeToken _native, uint256 _amount) external payable virtual whenNotPaused {
        _native.withdraw(_amount);
    }

    function unwrapAll(IWrappedNativeToken _native) external payable virtual whenNotPaused {
        uint256 balance = _native.balanceOf(address(this));
        _native.withdraw(balance);
    }

    /// @inheritdoc ISiloRouter
    function sendValue(address payable _to, uint256 _amount) external payable whenNotPaused {
        Address.sendValue(_to, _amount);
    }

    /// @inheritdoc ISiloRouter
    function sendValueAll(address payable _to) external payable whenNotPaused {
        uint256 balance = address(this).balance;
        Address.sendValue(_to, balance);
    }

    /// @inheritdoc ISiloRouter
    function transferFrom(IERC20 _token, address _to, uint256 _amount) external payable whenNotPaused {
        _token.safeTransferFrom(msg.sender, _to, _amount);
    }

    /// @inheritdoc ISiloRouter
    function transfer(IERC20 _token, address _to, uint256 _amount) external payable whenNotPaused {
        _token.safeTransfer(_to, _amount);
    }

    /// @inheritdoc ISiloRouter
    function approve(IERC20 _token, address _spender, uint256 _amount) external payable whenNotPaused {
        _token.forceApprove(_spender, _amount);
    }

    /// @inheritdoc ISiloRouter
    function deposit(ISilo _silo, uint256 _amount, ISilo.CollateralType _collateral) external payable whenNotPaused returns (uint256 shares) {
        shares = _silo.deposit(_amount, msg.sender, _collateral);
    }

    /// @inheritdoc ISiloRouter
    function withdraw(
        ISilo _silo,
        uint256 _amount,
        address _receiver,
        ISilo.CollateralType _collateral
    ) external payable whenNotPaused returns (uint256 assets) {
        assets = _silo.withdraw(_amount, _receiver, msg.sender, _collateral);
    }

    /// @inheritdoc ISiloRouter
    function withdrawAll(
        ISilo _silo,
        address _receiver,
        ISilo.CollateralType _collateral
    ) external payable whenNotPaused returns (uint256 assets) {
        uint256 sharesAmount = _silo.maxRedeem(msg.sender, _collateral);
        assets = _silo.redeem(sharesAmount, _receiver, msg.sender, _collateral);
    }

    /// @inheritdoc ISiloRouter
    function borrow(
        ISilo _silo,
        uint256 _assets,
        address _receiver
    ) external payable whenNotPaused returns (uint256 shares) {
        shares = _silo.borrow(_assets, _receiver, msg.sender);
    }

    /// @inheritdoc ISiloRouter
    function borrowSameAsset(
        ISilo _silo,
        uint256 _assets,
        address _receiver
    ) external payable whenNotPaused returns (uint256 shares) {
        shares = _silo.borrowSameAsset(_assets, _receiver, msg.sender);
    }

    /// @inheritdoc ISiloRouter
    function repay(
        ISilo _silo,
        uint256 _assets,
        address _borrower
    ) external payable whenNotPaused returns (uint256 shares) {
        shares = _silo.repay(_assets, _borrower);
    }

    /// @inheritdoc ISiloRouter
    function repayAll(ISilo _silo, address _borrower) external payable whenNotPaused returns (uint256 shares) {
        uint256 repayAmount = _silo.maxRepay(_borrower);
        IERC20 asset = IERC20(_silo.asset());

        asset.safeTransferFrom(msg.sender, address(this), repayAmount);
        asset.approve(address(_silo), repayAmount);

        shares = _silo.repay(repayAmount, _borrower);
    }

    /// @inheritdoc ISiloRouter
    function repayAllNative(IWrappedNativeToken _native, ISilo _silo, address _borrower) external payable whenNotPaused returns (uint256 shares) {
        uint256 repayAmount = _silo.maxRepay(_borrower);

        IWrappedNativeToken(_native).deposit{value: repayAmount}();

        IERC20(address(_native)).approve(address(_silo), repayAmount);

        shares = _silo.repay(repayAmount, _borrower);

        uint256 balance = address(this).balance;

        // send back any native token leftover
        if (balance != 0) {
            Address.sendValue(payable(msg.sender), balance);
        }
    }
}
