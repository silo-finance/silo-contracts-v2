// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {IVeDelegation} from "@balancer-labs/v2-interfaces/contracts/liquidity-mining/IVeDelegation.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";
import {IVeBoost} from "ve-silo/contracts/voting-escrow/interfaces/IVeBoost.sol";
import {VotingEscrowDelegationProxy} from "ve-silo/contracts/voting-escrow/VotingEscrowDelegationProxy.sol";
import {NullVotingEscrow} from "ve-silo/contracts/voting-escrow/NullVotingEscrow.sol";

import {IVotingEscrowDelegationProxy}
    from "ve-silo/contracts/voting-escrow/interfaces/IVotingEscrowDelegationProxy.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/deploy/VotingEscrowDelegationProxyDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract VotingEscrowDelegationProxyDeploy is CommonDeploy {
        function run() public returns (IVotingEscrowDelegationProxy proxy) {
            uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

            vm.startBroadcast(deployerPrivateKey);

            address nullVotingEscrow = address(new NullVotingEscrow());

            proxy = IVotingEscrowDelegationProxy(address(
                new VotingEscrowDelegationProxy(
                    IERC20(nullVotingEscrow),
                    IVeDelegation(getDeployedAddress(VeSiloContracts.VE_BOOST))
                )
            ));

            _registerDeployment(nullVotingEscrow, VeSiloContracts.NULL_VOTING_ESCROW);
            _registerDeployment(address(proxy), VeSiloContracts.VOTING_ESCROW_DELEGATION_PROXY);

            vm.stopBroadcast();

            _syncDeployments();
        }
}
