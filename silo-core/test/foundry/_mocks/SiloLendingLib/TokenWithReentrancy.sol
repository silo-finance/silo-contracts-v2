// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISiloLendingLibConsumerMock} from "./ISiloLendingLibConsumerMock.sol";

contract TokenWithReentrancy {
    event SiloAssetState(uint256 assets);

    function transferFrom(address, address, uint256) external returns (bool) {
        // reentering the `silo` contract and checking the state
        ISiloLendingLibConsumerMock silo = ISiloLendingLibConsumerMock(msg.sender);
        uint256 totalDebt = silo.getTotalDebt();

        // The state is emitted to simplify the test
        emit SiloAssetState(totalDebt);

        return true;
    }
}
