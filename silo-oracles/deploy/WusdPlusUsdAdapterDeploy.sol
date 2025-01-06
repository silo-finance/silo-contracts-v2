// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6;

import {CommonDeploy} from "./CommonDeploy.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {WusdPlusUsdAdapter} from "silo-oracles/contracts/custom/WusdPlusUsdAdapter.sol";
import {SiloOraclesContracts} from "./SiloOraclesContracts.sol";

/**
    FOUNDRY_PROFILE=oracles \
        forge script silo-oracles/deploy/WusdPlusUsdAdapterDeploy.s.sol \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract WusdPlusUsdAdapterDeploy is CommonDeploy {
    function run() public returns (WusdPlusUsdAdapter adapter) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address wusdPlus = getAddress(AddrKey.WUSD_PLUS);
        address usdPlusUsdAggregator = getAddress(AddrKey.CHAINLINK_USDPlus_USD_aggregator);

        vm.startBroadcast(deployerPrivateKey);

        adapter = new WusdPlusUsdAdapter(wusdPlus, usdPlusUsdAggregator);

        vm.stopBroadcast();

        _registerDeployment(address(adapter), SiloOraclesContracts.WUSD_PLUS_USD_ADAPTER);
    }
}
