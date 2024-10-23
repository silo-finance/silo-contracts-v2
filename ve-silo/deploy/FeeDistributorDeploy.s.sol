// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";

import {IVotingEscrow} from "balancer-labs/v2-interfaces/liquidity-mining/IVotingEscrow.sol";

import {FeeDistributor, IFeeDistributor} from "ve-silo/contracts/fees-distribution/FeeDistributor.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/deploy/FeeDistributorDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract FeeDistributorDeploy is CommonDeploy {
    uint256 public startTime = 1729423963;

    function run() public returns (IFeeDistributor feeDistributor) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address votingEscrow = getDeployedAddress(VeSiloContracts.VOTING_ESCROW);

        vm.startBroadcast(deployerPrivateKey);

        feeDistributor = IFeeDistributor(address(
            new FeeDistributor(IVotingEscrow(votingEscrow), startTime)
        ));
        
        vm.stopBroadcast();

        _registerDeployment(address(feeDistributor), VeSiloContracts.FEE_DISTRIBUTOR);
    }
}
