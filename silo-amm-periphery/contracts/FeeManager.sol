// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "./interfaces/IFeeManager.sol";

contract FeeManager is IFeeManager {
    /// @dev fee basis points
    uint256 constant public FEE_BP = 1e4;

    FeeSetup internal _protocolFee;

    modifier onlyFeeReceiver() {
        if (msg.sender != _protocolFee.receiver) revert ONLY_PROTOCOL_FEE_RECEIVER();
        _;
    }

    constructor(FeeSetup memory _fee) {
        _setupFee(_fee);
    }

    /// @dev set up protocol fee distribution
    function setupFee(FeeSetup calldata _fee) external virtual onlyFeeReceiver {
        _setupFee(_fee);
    }

    /// @dev main purpose is to claim fees, but can be used for rescue tokes as well
    /// contract should never store any tokens, so whatever is here is a fee, so we can claim all
    function claimFee(IERC20 _token) external virtual {
        unchecked {
            // if we underflow on -1, token transfer will throw, no need to check math twice
            // we leaving 1wei for gas optimisation
            _token.transfer(_protocolFee.receiver, _token.balanceOf(address(this)) - 1);
        }
    }

    function getFeeSetup() external virtual view returns (FeeSetup memory) {
        return _protocolFee;
    }

    function getFee() external virtual view returns (uint256) {
        return _protocolFee.percent;
    }

    function _setupFee(FeeSetup memory _fee) internal virtual {
        if (_fee.receiver == address(0)) revert ZERO_ADDRESS();
        if (_fee.receiver == _protocolFee.receiver && _fee.percent == _protocolFee.percent) revert NO_CHANGE();

        // arbitrary check: we do not allow for more than 10% fee, as 10% looks extreme enough
        if (_fee.percent > FEE_BP / 10) revert FEE_OVERFLOW();

        _protocolFee = _fee;
        emit FeeSetupChanged(_fee.receiver, _fee.percent);
    }
}
