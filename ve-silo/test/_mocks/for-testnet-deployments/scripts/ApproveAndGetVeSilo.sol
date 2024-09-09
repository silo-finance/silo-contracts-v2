// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";
import {Script} from "forge-std/Script.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {VeSiloDeployments, VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";
import {VeSiloMocksContracts} from "ve-silo/test/_mocks/for-testnet-deployments/deployments/VeSiloMocksContracts.sol";
import {IVeSilo} from "ve-silo/contracts/voting-escrow/interfaces/IVeSilo.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/scripts/ApproveAndGetVeSilo.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract TransferMockSiloTokenOwnership is Script {
    function run() external {
        AddrLib.init();
        VmLib.vm().label(AddrLib._ADDRESS_COLLECTION, "AddressesCollection");

        uint256 proposerPrivateKey = uint256(vm.envBytes32("PROPOSER_PRIVATE_KEY"));
        address proposer = vm.addr(proposerPrivateKey);

        string memory chainAlias = ChainsLib.chainAlias();

        address mockToken = VeSiloDeployments.get(VeSiloMocksContracts.SILO_TOKEN_LIKE, chainAlias);
        address veSilo = VeSiloDeployments.get(VeSiloContracts.VOTING_ESCROW, chainAlias);

        uint256 balance = IERC20(mockToken).balanceOf(proposer);

        vm.startBroadcast(proposerPrivateKey);

        IERC20(mockToken).approve(veSilo, type(uint256).max);
        IVeSilo(veSilo).create_lock(balance / 2, block.timestamp + 300 days);

        vm.stopBroadcast();
    }
}
