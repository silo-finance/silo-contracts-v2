// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6;

import {KeyValueStorage} from "silo-foundry-utils/key-value/KeyValueStorage.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

library SiloConfigsNames {
    string public constant ETH_USDC_UNI_V3_SILO = "ETH-USDC_UniswapV3_Silo";
}

library SiloDeployments {
    string constant public DEPLOYMENTS_FILE = "silo-core/deploy/silo/_siloDeployments.json";

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
        address shared = AddrLib.getAddress(_name);

        if (shared != address(0)) {
            return shared;
        }

        return KeyValueStorage.getAddress(
            DEPLOYMENTS_FILE,
            _chain,
            _name
        );
    }
}
