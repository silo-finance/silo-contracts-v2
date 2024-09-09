// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Ownable2Step} from "openzeppelin5/access/Ownable2Step.sol";

import {VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";

import {IChildChainGauge} from "balancer-labs/v2-interfaces/liquidity-mining/IChildChainGauge.sol";

import {IChildChainGaugeFactory} from "ve-silo/contracts/gauges/interfaces/IChildChainGaugeFactory.sol";
import {ChildChainGaugeFactory} from "ve-silo/contracts/gauges/l2-common/ChildChainGaugeFactory.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/deploy/ChildChainGaugeFactoryDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract ChildChainGaugeFactoryDeploy is CommonDeploy {
    string internal constant _BASE_DIR = "ve-silo/contracts/gauges/l2-common";
    string internal constant _VERSION = "1.0.0";

    function run() public returns (IChildChainGaugeFactory gaugeFactory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address l2Multisig = getAddress(AddrKey.L2_MULTISIG);
        address l2BalancerPseudoMinter = getDeployedAddress(VeSiloContracts.L2_BALANCER_PSEUDO_MINTER);
        address votingEscrowDelegationProxy = getDeployedAddress(VeSiloContracts.VOTING_ESCROW_DELEGATION_PROXY);

        vm.startBroadcast(deployerPrivateKey);

        address childChainGaugeImpl = _deploy(
            VeSiloContracts.CHILD_CHAIN_GAUGE,
            abi.encode(
                votingEscrowDelegationProxy,
                l2BalancerPseudoMinter,
                l2Multisig,
                _VERSION
            )
        );

        ChildChainGaugeFactory factory = new ChildChainGaugeFactory(
            IChildChainGauge(childChainGaugeImpl),
            _VERSION,
            _VERSION
        );

        Ownable2Step(address(factory)).transferOwnership(l2Multisig);

        vm.stopBroadcast();

        gaugeFactory = IChildChainGaugeFactory(address(factory));

        _registerDeployment(address(factory), VeSiloContracts.CHILD_CHAIN_GAUGE_FACTORY);
        _syncDeployments();
    }

    function _contractBaseDir() internal pure override virtual returns (string memory) {
        return _BASE_DIR;
    }
}
