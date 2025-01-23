// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Address} from "openzeppelin5/utils/Address.sol";
import {Pausable} from "openzeppelin5/utils/Pausable.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {Multicall} from "openzeppelin5/utils/Multicall.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {Address} from "openzeppelin5/utils/Address.sol";
import {ISilo} from "./interfaces/ISilo.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IWrappedNativeToken} from "./interfaces/IWrappedNativeToken.sol";


/// @title SiloRouter
/// @notice Silo Router is a utility contract that aims to improve UX. It can batch any number or combination
/// of actions (Deposit, Withdraw, Borrow, Repay) and execute them in a single transaction.
/// @dev SiloRouter requires only first action asset to be approved
/// @custom:security-contact security@silo.finance
contract SiloRouter is Ownable2Step, Pausable, Multicall {
    error EthTransferFailed();
    error InvalidInputLength();

    constructor (address _initialOwner) Ownable(_initialOwner) {}

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Example of flows

    // Flow for deposit wS to Silo:
    // - multicall{value: amount)(data);
    // - wrap(wS, amount);
    // - approve(wS, silo, amount);
    // - deposit(silo, amount, receiver);

    // Flow for withdraw wS from Silo:
    // - user approves router to withdraw wS
    // - withdraw(silo, amount, receiver);
    // - unwrap(wS, amount);
    // - sendValue(amount, receiver);

    function wrap(address _weth, uint256 _amount) external whenNotPaused {
        IWrappedNativeToken(_weth).deposit{value: _amount}();
    }

    function unwrap(address _weth, uint256 _amount) external whenNotPaused {
        IWrappedNativeToken(_weth).withdraw(_amount);
    }

    /// @dev Anyone can approve any contract to take assets from the router. It's critical that router never has any balance after the execution
    function approve(address _asset, address _to, uint256 _amount) external whenNotPaused {
        SafeERC20.forceApprove(IERC20(_asset), _to, _amount);
    }

    /// @dev Anyone can transfer assets from the router to any address. It's critical that router never has any balance after the execution
    function transfer(address _asset, address _to, uint256 _amount) external whenNotPaused {
        SafeERC20.safeTransfer(IERC20(_asset), _to, _amount);
    }

    /// @notice Transfer token from msg.sender to the router
    /// @dev `from` is msg.sender and `to` is the router because we are using user's approvals and we need to make sure that other users can't use them
    function transferFrom(address _asset, uint256 _amount) external whenNotPaused {
        // make sure that from is msg.sender because otherwise anyone would be able to use anyone's approvals to the router
        address from = msg.sender;
        address to = address(this);
        SafeERC20.safeTransferFrom(IERC20(_asset), from, to, _amount);
    }

    function deposit(address _silo, uint256 _assets, address _receiver)
        external
        whenNotPaused
        returns (uint256 shares)
    {
        return ISilo(_silo).deposit(_assets, _receiver);
    }

    /// @notice Withdraw assets from Silo
    /// @dev `owner` is msg.sender because we are using user's approvals and we need to make sure that other users can't use them
    function withdraw(address _silo, uint256 _assets, address _receiver)
        external
        whenNotPaused
        returns (uint256 assets)
    {
        address owner = msg.sender;
        return ISilo(_silo).withdraw(_assets, _receiver, owner);
    }

    // TODO
    // mint
    // redeem (security!)
    // repay
    // repayShares
    // borrow (security!)
    // borrowShares (security!)
    // permit

    function sendValue(address _to, uint256 _amount) external whenNotPaused {
        Address.sendValue(payable(_to), _amount);
    }

    /// @dev needed for unwrapping WETH
    receive() external payable whenNotPaused {
        // `execute` method calls `IWrappedNativeToken.withdraw()`
        // and we need to receive the withdrawn ETH unconditionally
    }
}
