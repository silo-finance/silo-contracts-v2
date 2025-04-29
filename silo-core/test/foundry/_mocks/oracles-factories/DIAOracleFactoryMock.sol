// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IDIAOracle} from "silo-oracles/contracts/interfaces/IDIAOracle.sol";

contract DIAOracleFactoryMock {
    address constant public MOCK_ORACLE_ADDR = address(2);

    function create(IDIAOracle.DIADeploymentConfig calldata, bytes32)
        external
        virtual
        returns (address oracle)
    {
        oracle = MOCK_ORACLE_ADDR;
    }
}
