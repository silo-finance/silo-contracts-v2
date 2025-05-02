// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6 <0.9.0;

import {Deployments} from "silo-foundry-utils/lib/Deployments.sol";

library XSiloContracts {
    string public constant SILO_GOVERNANCE_TOKEN_V2 = "SiloGovernanceTokenV2.sol";
}

library XSiloDeployments {
    string public constant DEPLOYMENTS_DIR = "x-silo";

    function get(string memory _contract, string memory _network) internal returns(address) {
        return Deployments.getAddress(DEPLOYMENTS_DIR, _network, _contract);
    }
}
