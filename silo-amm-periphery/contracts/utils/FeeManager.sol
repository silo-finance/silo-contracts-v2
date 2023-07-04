// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "../interfaces/IFeeManager.sol";

abstract contract FeeManager is IFeeManager {
    /// @dev fee basis points
    uint256 constant internal _FEE_BP = 1e4;

    Fee internal _protocolFee;

    modifier onlyFeeReceiver() {
        if (msg.sender != _protocolFee.receiver) revert ONLY_PROTOCOL_FEE_RECEIVER();
        _;
    }

    constructor(Fee memory _fee) {
        _feeSetup(_fee);
    }

    /// @dev set up protocol fee distribution
    function setFee(Fee calldata _fee) external onlyFeeReceiver {
        _feeSetup(_fee);
    }

    /// @dev main purpose is to claim fees, but can be used for rescue tokes as well
    /// contract should never store any tokens, so whatever is here is a fee, so we can claim all
    function claimFee(IERC20 _token) external {
        unchecked {
            // if we underflow on -1, token transfer will throw, no need to check math twice
            // we leaving 1wei for gas optimisation
            _token.transfer(_protocolFee.receiver, _token.balanceOf(address(this)) - 1);
        }
    }

    function protocolFee() external view returns (Fee memory) {
        return _protocolFee;
    }

    function _feeSetup(Fee memory _fee) internal {
        if (_fee.receiver == address(0)) revert ZERO_ADDRESS();
        if (_fee.receiver == _protocolFee.receiver && _fee.percent == _protocolFee.percent) revert NO_CHANGE();

        // arbitrary check: we do not allow for more than 10% fee, as 10% looks extreme enough
        if (_fee.percent > _FEE_BP / 10) revert FEE_OVERFLOW();

        _protocolFee = _fee;
        emit FeeSetup(_fee.receiver, _fee.percent);
    }
}
