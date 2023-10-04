// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;

import {KeyValueStorage} from "silo-foundry-utils/key-value/KeyValueStorage.sol";

library UniswapOracleConfig {
    string public constant ETH_USDC_0_3 = "UniV3-ETH-USDC-0.3";
}

library UniswapV3OracleDeployments {
    string constant public DEPLOYMENTS_FILE = "silo-oracles/deploy/uniswap-v3-oracle/_deployments.json";

    function save(
        string memory _chain,
        string memory _name,
        address _deployed
    ) internal {
        KeyValueStorage.setAddress(
            DEPLOYMENTS_FILE,
            _chain,
            _name,
            _deployed
        );
    }

    function get(string memory _chain, string memory _name) internal returns (address) {
        return KeyValueStorage.getAddress(
            DEPLOYMENTS_FILE,
            _chain,
            _name
        );
    }
}
