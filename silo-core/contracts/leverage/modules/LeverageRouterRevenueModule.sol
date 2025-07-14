// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable2Step} from "openzeppelin5/access/Ownable2Step.sol";

import {ILeverageRouter} from "silo-core/contracts/interfaces/ILeverageRouter.sol";

/// @title Leverage Router Revenue Module
abstract contract LeverageRouterRevenueModule is ILeverageRouter, Ownable2Step {
    /// @notice Fee base constant (1e18 represents 100%)
    uint256 public constant FEE_PRECISION = 1e18;
    /// @notice The leverage fee expressed as a fraction of 1e18
    uint256 public leverageFee;
    /// @notice Address where collected fees are sent
    address public revenueReceiver;

    /// @inheritdoc ILeverageRouter
    function setLeverageFee(uint256 _fee) external onlyOwner {
        require(revenueReceiver != address(0), ReceiverZero());
        require(leverageFee != _fee, FeeDidNotChanged());
        require(_fee < FEE_PRECISION, InvalidFee());

        leverageFee = _fee;
        emit LeverageFeeChanged(_fee);
    }

    /// @inheritdoc ILeverageRouter
    function setRevenueReceiver(address _receiver) external onlyOwner {
        require(revenueReceiver != _receiver, ReceiverDidNotChanged());
        require(_receiver != address(0), ReceiverZero());

        revenueReceiver = _receiver;
        emit RevenueReceiverChanged(_receiver);
    }
}
