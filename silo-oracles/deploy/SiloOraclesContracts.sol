// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9.0;

import {Deployments} from "silo-foundry-utils/lib/Deployments.sol";

library SiloOraclesContracts {
    string public constant UNISWAP_V3_ORACLE_FACTORY = "UniswapV3OracleFactory.sol";
}

library SiloOraclesDeployments {
    string public constant DEPLOYMENTS_DIR = "silo-oracles";

    function get(string memory _contract, string memory _network) internal returns(address) {
        return Deployments.getAddress(DEPLOYMENTS_DIR, _contract, _network);
    }
}
