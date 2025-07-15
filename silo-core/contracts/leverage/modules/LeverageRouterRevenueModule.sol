// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AccessControl} from "openzeppelin5/access/AccessControl.sol";
import {Pausable} from "openzeppelin5/utils/Pausable.sol";

import {ILeverageRouter} from "silo-core/contracts/interfaces/ILeverageRouter.sol";

/// @title Leverage Router Revenue Module
abstract contract LeverageRouterRevenueModule is ILeverageRouter, AccessControl, Pausable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    /// @notice Fee base constant (1e18 represents 100%)
    uint256 public constant FEE_PRECISION = 1e18;

    /// @notice The maximum leverage fee (5%)
    uint256 public constant MAX_LEVERAGE_FEE = 0.05e18; 

    /// @notice The leverage fee expressed as a fraction of 1e18
    uint256 public leverageFee;

    /// @notice Address where collected fees are sent
    address public revenueReceiver;

    /// @inheritdoc ILeverageRouter
    function setLeverageFee(uint256 _fee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(revenueReceiver != address(0), ReceiverZero());
        require(leverageFee != _fee, FeeDidNotChanged());
        require(_fee < MAX_LEVERAGE_FEE, InvalidFee());

        leverageFee = _fee;
        emit LeverageFeeChanged(_fee);
    }

    /// @inheritdoc ILeverageRouter
    function setRevenueReceiver(address _receiver) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(revenueReceiver != _receiver, ReceiverDidNotChanged());
        require(_receiver != address(0), ReceiverZero());

        revenueReceiver = _receiver;
        emit RevenueReceiverChanged(_receiver);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}
