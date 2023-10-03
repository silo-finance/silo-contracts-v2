// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {IVotingEscrow} from "balancer-labs/v2-interfaces/liquidity-mining/IVotingEscrow.sol";
import {IVotingEscrowRemapper} from "balancer-labs/v2-interfaces/liquidity-mining/IVotingEscrowRemapper.sol";

import {VotingEscrowRemapper} from "ve-silo/contracts/voting-escrow/VotingEscrowRemapper.sol";
import {VeSiloAddrKey} from "ve-silo/common/VeSiloAddresses.sol";

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";
import {IVotingEscrowCCIPRemapper} from "ve-silo/contracts/voting-escrow/interfaces/IVotingEscrowCCIPRemapper.sol";

contract VotingEscrowRemapperDeploy is CommonDeploy {
     function run() public returns (IVotingEscrowCCIPRemapper remapper) {
          uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

          vm.startBroadcast(deployerPrivateKey);

          
          IVotingEscrow votingEscrow = IVotingEscrow(getDeployedAddress(VeSiloContracts.VOTING_ESCROW));
          IERC20 link = IERC20(getAddress(VeSiloAddrKey.LINK));

          remapper = IVotingEscrowCCIPRemapper(new VotingEscrowRemapper(votingEscrow, link));
          _registerDeployment(address(remapper), VeSiloContracts.VOTING_ESCROW_REMAPPER);

          vm.stopBroadcast();

          _syncDeployments();
     }
}
