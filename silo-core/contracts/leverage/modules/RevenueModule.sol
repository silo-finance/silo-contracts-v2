// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";

abstract contract RevenueModule is Ownable2Step {
    using SafeERC20 for IERC20;

    uint256 public constant FEE_DECIMALS = 1e18;

    uint256 public leverageFee;

    address public revenueReceiver;

    event LeverageFeeChanged(uint256 leverageFee);
    event RevenueReceiverChanged(address indexed receiver);
    event LeverageRevenue(address indexed token, uint256 revenue, address indexed receiver);

    error FeeDidNotChanged();
    error ReceiverDidNotChanged();
    error ReceiverZero();
    error InvalidFee();
    error NoRevenue();
    error ReceiverNotSet();

    function setLeverageFee(uint256 _fee) external onlyOwner {
        require(leverageFee != _fee, FeeDidNotChanged());
        require(_fee < FEE_DECIMALS, InvalidFee());

        leverageFee = _fee;
        emit LeverageFeeChanged(_fee);
    }

    function setRevenueReceiver(address _receiver) external onlyOwner {
        require(revenueReceiver != _receiver, ReceiverDidNotChanged());
        require(_receiver != address(0), ReceiverZero());

        revenueReceiver = _receiver;
        emit RevenueReceiverChanged(_receiver);
    }

    function withdrawRevenues(IERC20[] calldata _tokens) external {
        for (uint256 i; i < _tokens.length; i++) {
            withdrawRevenue(_tokens[i]);
        }
    }

    function withdrawRevenue(IERC20 _token) public {
        uint256 balance = _token.balanceOf(address(this));
        require(balance != 0, NoRevenue());

        address receiver = revenueReceiver;
        require(receiver != address(0), ReceiverNotSet());

        _token.safeTransfer(receiver, balance);
        emit LeverageRevenue(address(_token), balance, receiver);
    }

    function _calculateLeverageFee(uint256 _amount) internal virtual returns (uint256 leverageFeeAmount) {
        uint256 fee = leverageFee;
        if (fee == 0) return 0;

        leverageFeeAmount = Math.mulDiv(_amount, fee, FEE_DECIMALS, Math.Rounding.Ceil);
        if (leverageFeeAmount == 0) leverageFeeAmount = 1;
    }

    function _transferFee(IERC20 _token, uint256 _totalDeposit) internal virtual returns (uint256 leverageFeeAmount) {
        leverageFeeAmount = _calculateLeverageFee(_totalDeposit);
        if (leverageFeeAmount == 0) return 0;

        _token.safeTransfer(revenueReceiver, leverageFeeAmount);
    }
}
