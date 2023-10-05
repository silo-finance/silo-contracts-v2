// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import {ISiloChildChainGauge} from "./ISiloChildChainGauge.sol";

/// @notice Checkpoint user in multiple gauges in a single transaction
interface IBatchGaugeCheckpointer {
    /// @dev Revert on an attempt to checkpoint an empty address
    error EmptyUser();

    /// @param _user A user to be checkpointed
    /// @param _gauges A list of gauges to checkpoint a `_user`
    function batchCheckpoint(address _user, ISiloChildChainGauge[] calldata _gauges) external;
}
