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

    function setFeedKey(string memory _feedKey) public {
        feedKey = _feedKey;
    }

    function run() public returns (WrappedMetaVaultOracleAdapter adapter) {
        AddrLib.init();

        if (bytes(feedKey).length == 0) {
            feedKey = vm.envString("FEED");
        }

        IWrappedMetaVaultOracle feed = IWrappedMetaVaultOracle(AddrLib.getAddress(feedKey));

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        adapter = new WrappedMetaVaultOracleAdapter(feed);

        vm.stopBroadcast();

        string memory oracleName = string.concat("WRAPPED_META_VAULT_", feedKey);
        OraclesDeployments.save(getChainAlias(), oracleName, address(adapter));
    }
}
