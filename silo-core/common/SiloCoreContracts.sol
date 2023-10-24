// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9.0;

import {Deployments} from "silo-foundry-utils/lib/Deployments.sol";

library SiloCoreContracts {
    // smart contracts list
    string public constant SILO_FACTORY = "SiloFactory.sol";
    string public constant INTEREST_RATE_MODEL_V2_CONFIG_FACTORY = "InterestRateModelV2ConfigFactory.sol";
    string public constant INTEREST_RATE_MODEL_V2 = "InterestRateModelV2.sol";
    string public constant GAUGE_HOOK_RECEIVER = "GaugeHookReceiver.sol";
    string public constant HOOK_RECEIVERS_FACTORY = "HookReceiversFactory.sol";
}

library SiloCoreDeployments {
    string public constant DEPLOYMENTS_DIR = "silo-core";

    function get(string memory _contract, string memory _network) internal returns(address) {
        return Deployments.getAddress(DEPLOYMENTS_DIR, _contract, _network);
    }
}
