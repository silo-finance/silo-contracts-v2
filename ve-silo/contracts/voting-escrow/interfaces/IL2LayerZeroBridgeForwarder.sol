// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IL2LayerZeroDelegation} from "balancer-labs/v2-interfaces/liquidity-mining/IL2LayerZeroDelegation.sol";

interface IL2LayerZeroBridgeForwarder is IL2LayerZeroDelegation {
    function setDelegation(IL2LayerZeroDelegation delegation) external;
    function getDelegationImplementation() external view returns (IL2LayerZeroDelegation);
}
