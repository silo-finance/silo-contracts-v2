// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";
import {IVeSilo} from "ve-silo/contracts/voting-escrow/interfaces/IVeSilo.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/deploy/VotingEscrowDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract VotingEscrowDeploy is CommonDeploy {
    string internal constant _BASE_DIR = "external/balancer-v2-monorepo/pkg/liquidity-mining/contracts";

    function run() public returns (IVeSilo votingEscrow) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        address votingEscrowAddr = _deploy(
            VeSiloContracts.VOTING_ESCROW,
            abi.encode(
                getAddress(SILO80_WETH20_TOKEN),
                votingEscrowName(),
                votingEscrowSymbol(),
                getDeployedAddress(VeSiloContracts.TIMELOCK_CONTROLLER)
            )
        );

        votingEscrow = IVeSilo(votingEscrowAddr);

        vm.stopBroadcast();

        _syncDeployments();
    }

    function votingEscrowName() public pure returns (string memory name) {
        name = new string(64);
        name = "Voting Escrow (Silo)";
    }

    function votingEscrowSymbol() public pure returns (string memory symbol) {
        symbol = new string(32);
        symbol = "veSILO";
    }

    function _contractBaseDir() internal pure override virtual returns (string memory) {
        return _BASE_DIR;
    }
}
