// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";

import {IVotingEscrow} from "balancer-labs/v2-interfaces/liquidity-mining/IVotingEscrow.sol";

import {FeeDistributor, IFeeDistributor} from "ve-silo/contracts/fees-distribution/FeeDistributor.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/deploy/FeesDistributorDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract FeesDistributorDeploy is CommonDeploy {
    uint256 public startTime = 1706745600;

    function run() public returns (IFeeDistributor feeDistributor) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        address votingEscrow = getDeployedAddress(VeSiloContracts.VOTING_ESCROW);

        feeDistributor = IFeeDistributor(address(
            new FeeDistributor(IVotingEscrow(votingEscrow), startTime)
        ));
        
        vm.stopBroadcast();

        _registerDeployment(address(feeDistributor), VeSiloContracts.FEES_DISTRIBUTOR);

        _syncDeployments();
    }
}
