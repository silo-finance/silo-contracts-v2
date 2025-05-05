// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Math} from "openzeppelin5/utils/math/Math.sol";

// TODO Ownable
contract RevenueModule {
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

    function setLeverageFee(uint256 _fee) external {
        require(leverageFee != _fee, FeeDidNotChanged());
        require(_fee < 1e18, InvalidFee());

        leverageFee = _fee;
        emit LeverageFeeChanged(_fee);
    }

    function setRevenueReceiver(address _receiver) external {
        require(revenueReceiver != _receiver, ReceiverDidNotChanged());
        require(_receiver != address(0), ReceiverZero());

        revenueReceiver = _receiver;
        emit RevenueReceiverChanged(_receiver);
    }

    function withdrawRevenue(IERC20 _token) external {
        uint256 balance = _token.balanceOf(address(this));
        require(balance != 0, NoRevenue());

        address receiver = revenueReceiver;
        require(receiver != address(0), ReceiverNotSet());

        _token.transfer(balance, receiver);
        emit LeverageRevenue(address(_token), balance, receiver);
    }

    function _calculateLeverageFee(uint256 _totalDeposit) internal virtual returns (uint256 leverageFeeAmount) {
        uint256 fee = leverageFee;
        if (fee == 0) return 0;

        leverageFeeAmount = Math.mulDiv(_totalDeposit, fee, FEE_DECIMALS, Math.Rounding.Ceil);
        if (leverageFeeAmount == 0) leverageFeeAmount = 1;
    }

    function _takeLeverageFee(uint256 _totalDeposit) internal virtual returns (uint256 leverageFeeAmount) {
        uint256 fee = leverageFee;
        if (fee == 0) return 0;

        leverageFeeAmount = _totalDeposit * fee / FEE_DECIMALS;
        if (leverageFeeAmount == 0) leverageFeeAmount = 1;
    }
}
