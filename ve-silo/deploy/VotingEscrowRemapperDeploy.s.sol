// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {IVotingEscrow} from "balancer-labs/v2-interfaces/liquidity-mining/IVotingEscrow.sol";
import {IVotingEscrowRemapper} from "balancer-labs/v2-interfaces/liquidity-mining/IVotingEscrowRemapper.sol";

import {CommonDeploy} from "./_CommonDeploy.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";

import {VotingEscrowRemapper} from "ve-silo/contracts/voting-escrow/VotingEscrowRemapper.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {IVotingEscrowCCIPRemapper} from "ve-silo/contracts/voting-escrow/interfaces/IVotingEscrowCCIPRemapper.sol";

contract VotingEscrowRemapperDeploy is CommonDeploy {
     function run() public returns (IVotingEscrowCCIPRemapper remapper) {
          uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
          address timelock = VeSiloDeployments.get(VeSiloContracts.TIMELOCK_CONTROLLER, getChainAlias());
          IVotingEscrow votingEscrow = IVotingEscrow(getDeployedAddress(VeSiloContracts.VOTING_ESCROW));
          IERC20 link = IERC20(getAddress(AddrKey.LINK));

          vm.startBroadcast(deployerPrivateKey);

          remapper = IVotingEscrowCCIPRemapper(new VotingEscrowRemapper(votingEscrow, link));

          Ownable(address(remapper)).transferOwnership(timelock);

          vm.stopBroadcast();

          _registerDeployment(address(remapper), VeSiloContracts.VOTING_ESCROW_REMAPPER);
     }
}
