// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";

import {AddrKey} from "common/addresses/AddrKey.sol";
import {IVotingEscrowChildChain} from "ve-silo/contracts/voting-escrow/interfaces/IVotingEscrowChildChain.sol";
import {VotingEscrowChildChain} from "ve-silo/contracts/voting-escrow/VotingEscrowChildChain.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/deploy/VotingEscrowChildChainDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract VotingEscrowChildChainDeploy is CommonDeploy {
    function run() public returns (IVotingEscrowChildChain votingEscrow) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        votingEscrow = IVotingEscrowChildChain(address(
            new VotingEscrowChildChain(
                getAddress(AddrKey.CHAINLINK_CCIP_ROUTER),
                _sourceChainSelector()
            )
        ));

        vm.stopBroadcast();

        _registerDeployment(address(votingEscrow), VeSiloContracts.VOTING_ESCROW_CHILD_CHAIN);
        _syncDeployments();
    }

    function _sourceChainSelector() internal returns (uint64 sourceChainSelector) {
         if (isChain(ANVIL_ALIAS) || isChain(SEPOLIA_ALIAS)) {
            return 1; // only for local tests
         }
    }
}
