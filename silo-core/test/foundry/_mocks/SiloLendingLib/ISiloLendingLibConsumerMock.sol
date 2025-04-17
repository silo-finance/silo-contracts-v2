// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

interface ISiloLendingLibConsumerMock {
    function getTotalDebt() external view returns (uint256);
}
