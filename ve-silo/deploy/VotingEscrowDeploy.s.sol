// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";
import {VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {IVeSilo} from "ve-silo/contracts/voting-escrow/interfaces/IVeSilo.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/deploy/VotingEscrowDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract VotingEscrowDeploy is CommonDeploy {
    string internal constant _BASE_DIR = "external/balancer-v2-monorepo/pkg/liquidity-mining/contracts";

    function run() public returns (IVeSilo votingEscrow) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address siloToken = AddrLib.getAddress(AddrKey.SILO_TOKEN);
        address timelock = VeSiloDeployments.get(VeSiloContracts.TIMELOCK_CONTROLLER, getChainAlias());

        vm.startBroadcast(deployerPrivateKey);

        address votingEscrowAddr = _deploy(
            VeSiloContracts.VOTING_ESCROW,
            abi.encode(
                siloToken,
                votingEscrowName(),
                votingEscrowSymbol(),
                timelock
            )
        );

        vm.stopBroadcast();

        votingEscrow = IVeSilo(votingEscrowAddr);

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
