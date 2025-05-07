// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IUniswapV3Oracle} from "silo-oracles/contracts/interfaces/IUniswapV3Oracle.sol";

contract UniswapV3OracleFactoryMock {
    address constant public MOCK_ORACLE_ADDR = address(3);

    function create(IUniswapV3Oracle.UniswapV3DeploymentConfig memory, bytes32)
        external
        virtual
        returns (address oracle)
    {
        oracle = MOCK_ORACLE_ADDR;
    }
}
