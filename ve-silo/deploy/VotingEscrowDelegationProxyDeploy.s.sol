// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IVeDelegation} from "@balancer-labs/v2-interfaces/contracts/liquidity-mining/IVeDelegation.sol";
import {IERC20} from "openzeppelin5/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {CommonDeploy} from "./_CommonDeploy.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {IVeBoost} from "ve-silo/contracts/voting-escrow/interfaces/IVeBoost.sol";
import {VotingEscrowDelegationProxy} from "ve-silo/contracts/voting-escrow/VotingEscrowDelegationProxy.sol";
import {NullVotingEscrow} from "ve-silo/contracts/voting-escrow/NullVotingEscrow.sol";

import {IVotingEscrowDelegationProxy}
    from "ve-silo/contracts/voting-escrow/interfaces/IVotingEscrowDelegationProxy.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/deploy/VotingEscrowDelegationProxyDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract VotingEscrowDelegationProxyDeploy is CommonDeploy {
        function run() public returns (IVotingEscrowDelegationProxy proxy) {
            uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
            address timelock = VeSiloDeployments.get(VeSiloContracts.TIMELOCK_CONTROLLER, getChainAlias());
            address veBoost = VeSiloDeployments.get(VeSiloContracts.VE_BOOST, getChainAlias());

            vm.startBroadcast(deployerPrivateKey);

            address nullVotingEscrow = address(new NullVotingEscrow());

            proxy = IVotingEscrowDelegationProxy(address(
                new VotingEscrowDelegationProxy(
                    IERC20(nullVotingEscrow),
                    IVeDelegation(veBoost)
                )
            ));

            Ownable(address(proxy)).transferOwnership(timelock);

            vm.stopBroadcast();

            _registerDeployment(nullVotingEscrow, VeSiloContracts.NULL_VOTING_ESCROW);
            _registerDeployment(address(proxy), VeSiloContracts.VOTING_ESCROW_DELEGATION_PROXY);
        }
}
