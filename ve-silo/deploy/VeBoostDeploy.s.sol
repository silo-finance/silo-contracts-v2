// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";
import {IVeBoost} from "ve-silo/contracts/voting-escrow/interfaces/IVeBoost.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/deploy/VeBoostDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract VeBoostDeploy is CommonDeploy {
    bool internal _isMainnetSimulation = false;
    string internal constant _BASE_DIR = "external/balancer-v2-monorepo/pkg/liquidity-mining/contracts";

    function run() public returns (IVeBoost veBoost) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address votingEscrow = _votingEscrowAddress();

        vm.startBroadcast(deployerPrivateKey);

         address veBoostAddr = _deploy(
            VeSiloContracts.VE_BOOST,
            abi.encode(
                address(0), // veBoostV1 - an empty address
                votingEscrow
            )
         );

        vm.stopBroadcast();

        veBoost = IVeBoost(veBoostAddr);

        _syncDeployments();
    }

    function enableMainnetSimulation() public {
        _isMainnetSimulation = true;
    }

    function _votingEscrowAddress() internal returns (address) {
        if (isChain(MAINNET_ALIAS) || isChain(ANVIL_ALIAS) || _isMainnetSimulation) {
            return getDeployedAddress(VeSiloContracts.VOTING_ESCROW);
        }

        return getDeployedAddress(VeSiloContracts.VOTING_ESCROW_CHILD_CHAIN);
    }

    function _contractBaseDir() internal pure override virtual returns (string memory) {
        return _BASE_DIR;
    }
}
