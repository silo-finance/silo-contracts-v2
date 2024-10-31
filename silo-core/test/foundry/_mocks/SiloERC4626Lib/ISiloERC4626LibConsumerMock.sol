// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

interface ISiloERC4626LibConsumerMock {
    function getTotalCollateral() external view returns (uint256);
}
