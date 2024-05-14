// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ISiloChildChainGauge} from "../interfaces/ISiloChildChainGauge.sol";
import {IBatchGaugeCheckpointer} from "../interfaces/IBatchGaugeCheckpointer.sol";

/// @notice Checkpoint user in multiple gauges in a single transaction
contract BatchGaugeCheckpointer is IBatchGaugeCheckpointer {
    /// @inheritdoc IBatchGaugeCheckpointer
    function batchCheckpoint(address _user, ISiloChildChainGauge[] calldata _gauges) external {
        if (_user == address(0)) revert EmptyUser();

        uint256 totalGauges = _gauges.length;

        for (uint256 i = 0; i < totalGauges;) {
            _gauges[i].user_checkpoint(_user);

            // We will never have so many gauges that we will overflow
            unchecked { i++; }
        }
    }
}
