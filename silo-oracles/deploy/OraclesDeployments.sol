// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6;

import {KeyValueStorage} from "silo-foundry-utils/key-value/KeyValueStorage.sol";

library OracleConfig {
    string public constant DAI_DEMO_CONFIG = "DIA_Demo_config";
    string public constant CHAINLINK_DEMO_CONFIG = "CHAINLINK_Demo_config";
    string public constant UNI_V3_ETH_USDC_03 = "UniV3-ETH-USDC-0.3";
}

library OraclesDeployments {
    string constant public DEPLOYMENTS_FILE = "silo-oracles/deploy/_oraclesDeployments.json";

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
