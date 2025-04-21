// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6;

import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";
import {PythAggregatorFactory} from "silo-oracles/contracts/pyth/PythAggregatorFactory.sol";
import {console2} from "forge-std/console2.sol";

/**
    FOUNDRY_PROFILE=oracles PAIR_NAME=EUR_USD PRICE_ID=0xa995d00bb36a63cef7fd2c287dc105fc8f3d93779f062f09551b0af3e81ec30b \
        forge script silo-oracles/deploy/pyth/PythAggregatorDeploy.s.sol \
        --ffi --rpc-url $RPC_URL --broadcast --verify
 */
contract PythAggregatorDeploy is CommonDeploy {
    function run() public returns (address aggregator) {
        PythAggregatorFactory factory =
            PythAggregatorFactory(getDeployedAddress(SiloOraclesFactoriesContracts.PYTH_AGGREGATOR_FACTORY));

        bytes32 priceId = vm.envBytes32("PRICE_ID");
        string memory pairName = vm.envString("PAIR_NAME");

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        aggregator = address(factory.deploy(priceId));

        vm.stopBroadcast();

        console2.log("Aggregator is deployed for", pairName, aggregator);
    }
}
