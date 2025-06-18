// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import {Deployer} from "silo-foundry-utils/deployer/Deployer.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {AddrKey} from "common/addresses/AddrKey.sol";

import {SiloCoreDeployments} from "silo-core/common/SiloCoreContracts.sol";

contract CommonDeploy is Deployer {
    // Common variables
    string internal constant _FORGE_OUT_DIR = "cache/foundry/out/silo-core";

    error UnsupportedNetworkForDeploy(string networkAlias);

    function _forgeOutDir() internal pure override virtual returns (string memory) {
        return _FORGE_OUT_DIR;
    }

    function _deploymentsSubDir() internal pure override virtual returns (string memory) {
        return SiloCoreDeployments.DEPLOYMENTS_DIR;
    }

    function _nativeToken() internal returns (address) {
        uint256 chainId = getChainId();

        if (chainId == ChainsLib.ANVIL_CHAIN_ID) return address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        if (chainId == ChainsLib.OPTIMISM_CHAIN_ID) return AddrLib.getAddress(AddrKey.WETH);
        if (chainId == ChainsLib.AVALANCHE_CHAIN_ID) return AddrLib.getAddress(AddrKey.WAVX);
        if (chainId == ChainsLib.ARBITRUM_ONE_CHAIN_ID) return AddrLib.getAddress(AddrKey.WETH);
        if (chainId == ChainsLib.MAINNET_CHAIN_ID) return AddrLib.getAddress(AddrKey.WETH);
        if (chainId == ChainsLib.SONIC_CHAIN_ID) return AddrLib.getAddress(AddrKey.wS);
        if (chainId == ChainsLib.INK_CHAIN_ID) return AddrLib.getAddress(AddrKey.WETH);

        revert(string.concat("can not find native token for ", ChainsLib.chainAlias()));
    }
}
