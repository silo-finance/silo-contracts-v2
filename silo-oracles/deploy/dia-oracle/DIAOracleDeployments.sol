// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {KeyValueStorage} from "silo-foundry-utils/key-value/KeyValueStorage.sol";

library DIAOracleConfig {
    string public constant DEMO_CONFIG = "demo-config";
}

library DIAOracleDeployments {
    string constant public DEPLOYMENTS_FILE = "silo-oracles/deploy/dia-oracle/_deployments.json";

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
