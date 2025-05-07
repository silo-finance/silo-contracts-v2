// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IChainlinkV3Oracle} from "silo-oracles/contracts/interfaces/IChainlinkV3Oracle.sol";

contract ChainlinkV3OracleFactoryMock {
    address constant public MOCK_ORACLE_ADDR = address(1);

    function create(IChainlinkV3Oracle.ChainlinkV3DeploymentConfig memory, bytes32)
        external
        virtual
        returns (address oracle)
    {
        oracle = MOCK_ORACLE_ADDR;
    }
}
