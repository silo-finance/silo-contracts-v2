// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";

import {OraclesDeployments} from "silo-oracles/deploy/OraclesDeployments.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

abstract contract SaveDeployedOracle {
    function _saveDeployedOracle(address _oracle, string memory _name) internal {
        OraclesDeployments.save(ChainsLib.chainAlias(), _name, _oracle);

        console2.log("\n--------------------------------\nsaved oracle \n\t%s:\n\t%s\n", _name, _oracle);
    }
}
