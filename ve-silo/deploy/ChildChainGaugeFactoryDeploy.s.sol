// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {IChildChainGauge} from "balancer-labs/v2-interfaces/liquidity-mining/IChildChainGauge.sol";

import {IChildChainGaugeFactory} from "ve-silo/contracts/gauges/interfaces/IChildChainGaugeFactory.sol";
import {ChildChainGaugeFactory} from "ve-silo/contracts/gauges/l2-common/ChildChainGaugeFactory.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/deploy/ChildChainGaugeFactoryDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract ChildChainGaugeFactoryDeploy is CommonDeploy {
    string internal constant _BASE_DIR = "ve-silo/contracts/gauges/l2-common";
    string internal constant _VERSION = "1.0.0";

    function run() public returns (IChildChainGaugeFactory gaugeFactory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        address childChainGaugeImpl = _deploy(
            VeSiloContracts.CHILD_CHAIN_GAUGE,
            abi.encode(
                getDeployedAddress(VeSiloContracts.VOTING_ESCROW_DELEGATION_PROXY),
                getDeployedAddress(VeSiloContracts.L2_BALANCER_PSEUDO_MINTER),
                getAddress(AddrKey.L2_MULTISIG),
                _VERSION
            )
        );

        ChildChainGaugeFactory factory = new ChildChainGaugeFactory(
            IChildChainGauge(childChainGaugeImpl),
            _VERSION,
            _VERSION
        );

        _registerDeployment(address(factory), VeSiloContracts.CHILD_CHAIN_GAUGE_FACTORY);

        gaugeFactory = IChildChainGaugeFactory(address(factory));

        vm.stopBroadcast();

        _syncDeployments();
    }

    function _contractBaseDir() internal pure override virtual returns (string memory) {
        return _BASE_DIR;
    }
}
