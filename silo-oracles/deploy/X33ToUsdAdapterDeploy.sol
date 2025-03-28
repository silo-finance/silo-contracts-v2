// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6;

import {CommonDeploy} from "./CommonDeploy.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {X33ToUsdAdapter, AggregatorV3Interface} from "silo-oracles/contracts/custom/X33ToUsdAdapter.sol";
import {SiloOraclesContracts} from "./SiloOraclesContracts.sol";

/**
    FOUNDRY_PROFILE=oracles \
        forge script silo-oracles/deploy/X33ToUsdAdapterDeploy.sol \
        --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract X33ToUsdAdapterDeploy is CommonDeploy {
    function run() public returns (X33ToUsdAdapter adapter) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        AggregatorV3Interface shadowUsdFeed =
            AggregatorV3Interface(AddrLib.getAddress(AddrKey.PYTH_SHADOW_USD_aggregator));

        vm.startBroadcast(deployerPrivateKey);

        adapter = new X33ToUsdAdapter(shadowUsdFeed);

        vm.stopBroadcast();

        _registerDeployment(address(adapter), SiloOraclesContracts.X33_TO_USD_ADAPTER);
    }
}
