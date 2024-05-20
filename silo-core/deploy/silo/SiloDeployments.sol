// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6;

import {KeyValueStorage} from "silo-foundry-utils/key-value/KeyValueStorage.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

library SiloConfigsNames {
    string public constant LOCAL_NO_ORACLE_SILO = "Local_noOracle";
    string public constant LOCAL_NO_ORACLE_NO_LTV_SILO = "Local_noOracleNoLtv";
    string public constant LOCAL_NOT_BORROWABLE = "Local_notBorrowable";
    string public constant LOCAL_BEFORE_CALL = "Local_beforeCall";
    string public constant LOCAL_DEPLOYER = "Local_deployer";
    string public constant LOCAL_HOOKS_MISSCONFIGURATION = "Local_HookMissconfiguration";
    string public constant LOCAL_GAUGE_HOOK_RECEIVER = "Local_gauge_hook_receiver";
    string public constant LOCAL_INVALID_CONTRACTS = "Local_invalidContracts";
    string public constant ETH_USDC_UNI_V3_SILO_NO_HOOK = "ETH-USDC_UniswapV3_Silo_no_hook";

    string public constant FULL_CONFIG_TEST = "FULL_CONFIG_TEST";
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
