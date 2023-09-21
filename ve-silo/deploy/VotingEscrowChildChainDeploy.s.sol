// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";

import {VeSiloAddrKey} from "ve-silo/common/VeSiloAddresses.sol";
import {IVotingEscrowChildChain} from "ve-silo/contracts/voting-escrow/interfaces/IVotingEscrowChildChain.sol";
import {VotingEscrowChildChain} from "ve-silo/contracts/voting-escrow/VotingEscrowChildChain.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/deploy/VotingEscrowChildChainDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract VotingEscrowChildChainDeploy is CommonDeploy {
    function run() public returns (IVotingEscrowChildChain delegator) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        delegator = IVotingEscrowChildChain(address(
            new VotingEscrowChildChain(
                getAddress(VeSiloAddrKey.CHAINLINK_CCIP_ROUTER),
                _sourceChainSelector()
            )
        ));

        vm.stopBroadcast();

        _registerDeployment(address(delegator), VeSiloContracts.VE_SILO_DELEGATOR_VIA_CCIP);
        _syncDeployments();
    }

    function _sourceChainSelector() internal returns (uint64 sourceChainSelector) {
         if (isChain(ANVIL_ALIAS)) {
            return 1; // only for local tests
         }
    }
}
