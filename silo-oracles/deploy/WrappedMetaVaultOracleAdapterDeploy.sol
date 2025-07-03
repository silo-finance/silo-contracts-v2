// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6;

import {CommonDeploy} from "./CommonDeploy.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {SiloOraclesContracts} from "./SiloOraclesContracts.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {OraclesDeployments} from "./OraclesDeployments.sol";
import {
    WrappedMetaVaultOracleAdapter,
    IWrappedMetaVaultOracle
} from "silo-oracles/contracts/custom/wrappedMetaVaultOracle/WrappedMetaVaultOracleAdapter.sol";

/**
    FOUNDRY_PROFILE=oracles FEED=wmetaUSD_USD_wMetaVault_aggregator \
        forge script silo-oracles/deploy/WrappedMetaVaultOracleAdapterDeploy.sol \
        --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract WrappedMetaVaultOracleAdapterDeploy is CommonDeploy {
    string public feedKey;
    bool feedKeySetByFunction;

    function setFeedKey(string memory _feedKey) public {
        feedKey = _feedKey;
        feedKeySetByFunction = true;
    }

    function run() public returns (WrappedMetaVaultOracleAdapter adapter) {
        AddrLib.init();

        if (!feedKeySetByFunction) {
            feedKey = vm.envString("FEED");
        }

        IWrappedMetaVaultOracle feed = IWrappedMetaVaultOracle(AddrLib.getAddress(feedKey));

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);
        adapter = new WrappedMetaVaultOracleAdapter(feed);
        vm.stopBroadcast();

        // fixes Sonic chainId not found in unit tests
        if (!feedKeySetByFunction) {
            string memory oracleName = string.concat("WRAPPED_META_VAULT_ADAPTER_", feedKey);
            OraclesDeployments.save(getChainAlias(), oracleName, address(adapter));
        }
    }
}
