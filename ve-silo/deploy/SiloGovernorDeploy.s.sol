// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";
import {TimelockController} from "openzeppelin5/governance/extensions/GovernorTimelockControl.sol";

import {SiloGovernor} from "ve-silo/contracts/governance/SiloGovernor.sol";
import {ISiloGovernor} from "ve-silo/contracts/governance/interfaces/ISiloGovernor.sol";
import {IVeSilo} from "ve-silo/contracts/voting-escrow/interfaces/IVeSilo.sol";
import {IVeBoost} from "ve-silo/contracts/voting-escrow/interfaces/IVeBoost.sol";
import {ISiloTimelockController} from "ve-silo/contracts/governance/interfaces/ISiloTimelockController.sol";

import {VotingEscrowDeploy} from "./VotingEscrowDeploy.s.sol";
import {VeBoostDeploy} from "./VeBoostDeploy.s.sol";
import {TimelockControllerDeploy} from "./TimelockControllerDeploy.s.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/deploy/SiloGovernorDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract SiloGovernorDeploy is CommonDeploy {
    VotingEscrowDeploy public votingEscrowDeploy = new VotingEscrowDeploy();
    VeBoostDeploy public veBoostDeploy = new VeBoostDeploy();
    TimelockControllerDeploy public timelockControllerDeploy = new TimelockControllerDeploy();

    function run()
        public
        returns (
            ISiloGovernor siloGovernor,
            ISiloTimelockController timelock,
            IVeSilo votingEscrow,
            IVeBoost veBoost
        )
    {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        timelock = timelockControllerDeploy.run();
        votingEscrow = votingEscrowDeploy.run();
        veBoost = veBoostDeploy.run();

        vm.startBroadcast(deployerPrivateKey);

        siloGovernor = ISiloGovernor(
            address(
                new SiloGovernor(
                    TimelockController(payable(address(timelock))),
                    votingEscrow
                )
            )
        );

        vm.stopBroadcast();

        _registerDeployment(address(siloGovernor), VeSiloContracts.SILO_GOVERNOR);

        _configure(siloGovernor, timelock);
    }

    function _configure(ISiloGovernor _governor, ISiloTimelockController _timelock) internal {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address deployer = vm.addr(deployerPrivateKey);
        address governorAddr = address(_governor);

        vm.startBroadcast(deployerPrivateKey);

        // Set the DAO as a proposer, an executor and a canceller
        _timelock.grantRole(_timelock.PROPOSER_ROLE(), governorAddr);
        _timelock.grantRole(_timelock.EXECUTOR_ROLE(), governorAddr);
        _timelock.grantRole(_timelock.CANCELLER_ROLE(), governorAddr);

        // Update TimelockController admin role
        _timelock.grantRole(_timelock.DEFAULT_ADMIN_ROLE(), governorAddr);
        _timelock.revokeRole(_timelock.DEFAULT_ADMIN_ROLE(), deployer);

        vm.stopBroadcast();
    }
}
