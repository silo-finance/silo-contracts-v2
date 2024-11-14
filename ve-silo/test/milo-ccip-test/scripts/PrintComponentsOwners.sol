// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";
import {Script} from "forge-std/Script.sol";
import {Ownable2Step} from "openzeppelin5/access/Ownable2Step.sol";

import {VeSiloDeployments, VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";
import {SiloCoreDeployments, SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";

import {console} from "forge-std/console.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/milo-ccip-test/scripts/PrintComponentsOwners.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract PrintComponentsOwners is Script {
    function run() external {
        AddrLib.init();
        VmLib.vm().label(AddrLib._ADDRESS_COLLECTION, "AddressesCollection");

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address devAddr = vm.addr(deployerPrivateKey);

        string memory chainAlias = ChainsLib.chainAlias();

        address balancerTokenAdmin = VeSiloDeployments.get(VeSiloContracts.BALANCER_TOKEN_ADMIN, chainAlias);

        console.log("BALANCER_TOKEN_ADMIN:", balancerTokenAdmin);

        _printVeSiloContractOwner(VeSiloContracts.MILO_TOKEN, chainAlias);

        address timelock = VeSiloDeployments.get(VeSiloContracts.TIMELOCK_CONTROLLER, chainAlias);

        console.log("Deployer:", devAddr);
        console.log("Timelock:", timelock);

        _printVeSiloContractOwner(VeSiloContracts.BALANCER_TOKEN_ADMIN, chainAlias);
        _printVeSiloContractOwner(VeSiloContracts.CCIP_GAUGE_CHECKPOINTER, chainAlias);
        _printVeSiloContractOwner(VeSiloContracts.GAUGE_ADDER, chainAlias);
        _printVeSiloContractOwner(VeSiloContracts.SMART_WALLET_CHECKER, chainAlias);
        _printVeSiloContractOwner(VeSiloContracts.STAKELESS_GAUGE_CHECKPOINTER_ADAPTOR, chainAlias);
        _printVeSiloContractOwner(VeSiloContracts.VOTING_ESCROW_REMAPPER, chainAlias);
        _printVeSiloContractOwner(VeSiloContracts.VOTING_ESCROW_DELEGATION_PROXY, chainAlias);
        _printVeSiloContractOwner(VeSiloContracts.LIQUIDITY_GAUGE_FACTORY, chainAlias);

        _printSiloCoreContractOwner(SiloCoreContracts.SILO_FACTORY, chainAlias);
    }

    function _printVeSiloContractOwner(string memory _contract, string memory _chain) internal {
        address contractAddr = VeSiloDeployments.get(_contract, _chain);
        console.log(_contract, "owner:", Ownable2Step(contractAddr).owner());
    }

    function _printSiloCoreContractOwner(string memory _contract, string memory _chain) internal {
        address contractAddr = SiloCoreDeployments.get(_contract, _chain);

        console.log(_contract, "owner:", Ownable2Step(contractAddr).owner());
    }
}
