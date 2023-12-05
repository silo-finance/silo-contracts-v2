// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6;

import {KeyValueStorage} from "silo-foundry-utils/key-value/KeyValueStorage.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

library ChildChainGaugesDeployments {
    string constant public DEPLOYMENTS_FILE =
        "ve-silo/deploy/gauges/child-chain-gauge/_childChainGaugesDeployments.json";

    function save(
        string memory _chain,
        string memory _silo,
        string memory _asset,
        string memory _token,
        address _gauge
    ) internal {
        string memory key = string(abi.encodePacked(_silo, "/", _asset, "/", _token));

        KeyValueStorage.setAddress(
            DEPLOYMENTS_FILE,
            _chain,
            key,
            _gauge
        );
    }

    function get(string memory _chain, string memory _key) internal returns (address) {
        address shared = AddrLib.getAddress(_key);

        if (shared != address(0)) {
            return shared;
        }

        return KeyValueStorage.getAddress(
            DEPLOYMENTS_FILE,
            _chain,
            _key
        );
    }
}
