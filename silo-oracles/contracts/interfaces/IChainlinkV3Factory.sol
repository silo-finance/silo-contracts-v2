// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IChainlinkV3Oracle} from "./IChainlinkV3Oracle.sol";

interface IChainlinkV3Factory {
    function create(IChainlinkV3Oracle.ChainlinkV3DeploymentConfig memory _config, bytes32 _externalSalt)
        external
        returns (address oracle);
}
