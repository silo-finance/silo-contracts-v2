// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {OmniVotingEscrow} from "lz_gauges/OmniVotingEscrow.sol";

import {IVotingEscrow} from "balancer-labs/v2-interfaces/liquidity-mining/IVotingEscrow.sol";
import {IOmniVotingEscrowAdaptor} from "balancer-labs/v2-interfaces/liquidity-mining/IOmniVotingEscrowAdaptor.sol";

import {IOmniVotingEscrowAdaptorSettings}
     from "balancer-labs/v2-interfaces/liquidity-mining/IOmniVotingEscrowAdaptorSettings.sol";

import {IVotingEscrowRemapper} from "balancer-labs/v2-interfaces/liquidity-mining/IVotingEscrowRemapper.sol";
import {IOmniVotingEscrow} from "balancer-labs/v2-interfaces/liquidity-mining/IOmniVotingEscrow.sol";

import {IVeSilo} from "ve-silo/contracts/voting-escrow/interfaces/IVeSilo.sol";
import {VotingEscrowRemapper} from "ve-silo/contracts/voting-escrow/VotingEscrowRemapper.sol";
import {OmniVotingEscrowAdaptor} from "ve-silo/contracts/voting-escrow/OmniVotingEscrowAdaptor.sol";

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";
import {VeSiloAddresses} from "./_VeSiloAddresses.sol";

contract VotingEscrowRemapperDeploy is CommonDeploy, VeSiloAddresses {
     function run()
          public
          returns (
               IOmniVotingEscrow omniVotingEscrow,
               IOmniVotingEscrowAdaptor adaptor,
               IVotingEscrowRemapper remapper
          )
     {
          uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

          vm.startBroadcast(deployerPrivateKey);

          adaptor = IOmniVotingEscrowAdaptor(address(new OmniVotingEscrowAdaptor()));
          _registerDeployment(address(adaptor), VeSiloContracts.OMNI_VOTING_ESCROW_ADAPTER);

          IVotingEscrow votingEscrow = IVotingEscrow(getDeployedAddress(VeSiloContracts.VOTING_ESCROW));

          remapper = IVotingEscrowRemapper(new VotingEscrowRemapper(votingEscrow, adaptor));
          _registerDeployment(address(remapper), VeSiloContracts.VOTING_ESCROW_REMAPPER);

          omniVotingEscrow = IOmniVotingEscrow(address(new OmniVotingEscrow(
               getAddress(LZ_ENDPOINT),
               address(remapper)
          )));

          _registerDeployment(address(omniVotingEscrow), VeSiloContracts.OMNI_VOTING_ESCROW);

          // configure OmniVotingEscrowAdaptor
          IOmniVotingEscrowAdaptorSettings(address(adaptor)).setOmniVotingEscrow(omniVotingEscrow);

          vm.stopBroadcast();

          _syncDeployments();
     }
}
