// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface IFeeManager {
    struct Fee {
        /// @param address of fee receiver
        address receiver;
        /// @param percent in 6 decimal points 100% == 1e6
        uint24 percent;
    }

    /// @param feeReceiver fee manager and receiver
    /// @param feePercent fee percent
    event FeeSetup(address feeReceiver, uint24 feePercent);

    error ONLY_PROTOCOL_FEE_RECEIVER();
    error ZERO_ADDRESS();
    error FEE_OVERFLOW();
    error NO_CHANGE();

    /// @dev set up protocol fee distribution
    function setFee(Fee calldata _fee) external;

    /// @dev main purpose is to claim fees, but can be used for rescue tokes as well
    /// contract should never store any tokens, so whatever is here is a fee, so we can claim all
    function claimFee(IERC20 _token) external;

    function protocolFee() external view returns (Fee memory);
}
