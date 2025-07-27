// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6;

import {CommonDeploy} from "./CommonDeploy.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {WstEthToStEthAdapterMainnet} from "silo-oracles/contracts/custom/WstEthToStEthAdapterMainnet.sol";
import {SiloOraclesContracts} from "./SiloOraclesContracts.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";

/**
    FOUNDRY_PROFILE=oracles \
        forge script silo-oracles/deploy/WstEthToStEthAdapterMainnetDeploy.sol \
        --ffi --rpc-url $RPC_MAINNET --broadcast --verify
 */
contract WstEthToStEthAdapterMainnetDeploy is CommonDeploy {
    function run() public returns (WstEthToStEthAdapterMainnet adapter) {
        if (!Strings.equal(ChainsLib.chainAlias(), ChainsLib.MAINNET_ALIAS)) {
            revert("Unsupported chain for WstEthToStEthAdapter");
        }

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        adapter = new WstEthToStEthAdapterMainnet();

        vm.stopBroadcast();

        _registerDeployment(address(adapter), SiloOraclesContracts.WSTETH_TO_STETH_ADAPTER_MAINNET);
    }
}
