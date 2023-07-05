// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface IFeeManager {
    struct FeeSetup {
        /// @param address of fee receiver
        address receiver;
        /// @param percent in 6 decimal points 100% == 1e6
        uint24 percent;
    }

    /// @param feeReceiver fee manager and receiver
    /// @param feePercent fee percent
    event FeeSetupChanged(address feeReceiver, uint24 feePercent);

    error ZERO_ADDRESS();
    error FEE_OVERFLOW();
    error NO_CHANGE();

    /// @dev set up protocol fee distribution
    function setupFee(FeeSetup calldata _fee) external;

    /// @dev main purpose is to claim fees, but can be used for rescue tokes as well
    /// contract should never store any tokens, so whatever is here is a fee, so we can claim all
    function claimFee(IERC20 _token) external;

    function getFeeSetup() external view returns (FeeSetup memory);
    function getFee() external view returns (uint256);
    function FEE_BP() external view returns (uint256);
}
