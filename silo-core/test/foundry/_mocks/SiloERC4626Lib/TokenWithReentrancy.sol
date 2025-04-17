// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISiloERC4626LibConsumerMock} from "./ISiloERC4626LibConsumerMock.sol";

contract TokenWithReentrancy {
    event SiloAssetState(uint256 assets);

    function transferFrom(address, address, uint256) external returns (bool) {
        // reentering the `silo` contract and checking the state
        ISiloERC4626LibConsumerMock silo = ISiloERC4626LibConsumerMock(msg.sender);
        uint256 totalCollateral = silo.getTotalCollateral();

        // The state is emitted to simplify the test
        emit SiloAssetState(totalCollateral);

        return true;
    }
}
