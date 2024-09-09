// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";
import {Script} from "forge-std/Script.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {VeSiloDeployments, VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";
import {ISiloGovernor, IGovernor} from "ve-silo/contracts/governance/interfaces/ISiloGovernor.sol";
import {VeSiloMocksContracts} from "ve-silo/test/_mocks/for-testnet-deployments/deployments/VeSiloMocksContracts.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/scripts/UserDetails.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract UserDetails is Script {
    function run() external returns (uint256 siloBalance, uint256 veSiloBalance, uint256 blockTimestamp) {
        AddrLib.init();
        VmLib.vm().label(AddrLib._ADDRESS_COLLECTION, "AddressesCollection");

        uint256 proposerPrivateKey = uint256(vm.envBytes32("PROPOSER_PRIVATE_KEY"));
        address proposer = vm.addr(proposerPrivateKey);

        string memory chainAlias = ChainsLib.chainAlias();

        address siloToken = VeSiloDeployments.get(VeSiloMocksContracts.SILO_TOKEN_LIKE, chainAlias);
        address veSilo = VeSiloDeployments.get(VeSiloContracts.VOTING_ESCROW, chainAlias);

        siloBalance = IERC20(siloToken).balanceOf(proposer);
        veSiloBalance = IERC20(veSilo).balanceOf(proposer);
        blockTimestamp = block.timestamp;
    }
}
