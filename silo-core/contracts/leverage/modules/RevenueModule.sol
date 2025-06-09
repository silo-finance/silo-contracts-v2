// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Pausable} from "openzeppelin5/utils/Pausable.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";

/// @title Revenue Module for Leverage Operations
/// @notice This contract collects and distributes revenue from leveraged operations.
abstract contract RevenueModule is Ownable2Step, Pausable {
    using SafeERC20 for IERC20;

    /// @notice Fee base constant (1e18 represents 100%)
    uint256 public constant FEE_PRECISION = 1e18;

    /// @notice The leverage fee expressed as a fraction of 1e18
    uint256 public leverageFee;

    /// @notice Address where collected fees are sent
    address public revenueReceiver;

    /// @notice Emitted when the leverage fee is updated
    /// @param leverageFee New leverage fee
    event LeverageFeeChanged(uint256 leverageFee);

    /// @notice Emitted when the revenue receiver address is changed
    /// @param receiver New receiver address
    event RevenueReceiverChanged(address indexed receiver);

    /// @notice Emitted when leverage revenue is withdrawn
    /// @param token Address of the token
    /// @param revenue Amount withdrawn
    /// @param receiver Address that received the funds
    event LeverageRevenue(address indexed token, uint256 revenue, address indexed receiver);

    /// @dev Thrown when trying to set the same fee as the current one
    error FeeDidNotChanged();

    /// @dev Thrown when trying to set the same revenue receiver
    error ReceiverDidNotChanged();

    /// @dev Thrown when the receiver address is zero
    error ReceiverZero();

    /// @dev Thrown when the provided fee is invalid (>= 100%)
    error InvalidFee();

    /// @dev Thrown when there is no revenue to withdraw
    error NoRevenue();

    /// @dev Thrown when revenue receiver is not set
    error ReceiverNotSet();

    function pause() external virtual onlyOwner {
        _pause();
    }

    function unpause() external virtual onlyOwner {
        _unpause();
    }

    /// @notice Set the leverage fee
    /// @param _fee New leverage fee (must be < FEE_PRECISION)
    function setLeverageFee(uint256 _fee) external onlyOwner {
        require(revenueReceiver != address(0), ReceiverZero());
        require(leverageFee != _fee, FeeDidNotChanged());
        require(_fee < FEE_PRECISION, InvalidFee());

        leverageFee = _fee;
        emit LeverageFeeChanged(_fee);
    }

    /// @notice Set the address that receives collected revenue
    /// @param _receiver New address to receive fees
    function setRevenueReceiver(address _receiver) external onlyOwner {
        require(revenueReceiver != _receiver, ReceiverDidNotChanged());
        require(_receiver != address(0), ReceiverZero());

        revenueReceiver = _receiver;
        emit RevenueReceiverChanged(_receiver);
    }

    /// @param _tokens List of tokens to rescue
    function rescueTokens(IERC20[] calldata _tokens) external {
        for (uint256 i; i < _tokens.length; i++) {
            rescueTokens(_tokens[i]);
        }
    }

    /// @param _token ERC20 token to rescue
    function rescueTokens(IERC20 _token) public {
        uint256 balance = _token.balanceOf(address(this));
        require(balance != 0, NoRevenue());

        address receiver = revenueReceiver;
        require(receiver != address(0), ReceiverNotSet());

        _token.safeTransfer(receiver, balance);
        emit LeverageRevenue(address(_token), balance, receiver);
    }

    /// @notice Calculates the leverage fee for a given amount
    /// @dev Will always return at least 1 if fee > 0 and calculation rounds down
    /// @param _amount The amount to calculate the fee for
    /// @return leverageFeeAmount The calculated fee amount
    function calculateLeverageFee(uint256 _amount) public virtual view returns (uint256 leverageFeeAmount) {
        uint256 fee = leverageFee;
        if (fee == 0) return 0;

        leverageFeeAmount = Math.mulDiv(_amount, fee, FEE_PRECISION, Math.Rounding.Ceil);
        if (leverageFeeAmount == 0) leverageFeeAmount = 1;
    }

    function _payLeverageFee(address _token, uint256 _leverageFee) internal virtual {
        if (_leverageFee != 0) IERC20(_token).safeTransfer(revenueReceiver, _leverageFee);
    }
}
