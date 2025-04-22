// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC4626} from "openzeppelin5/token/ERC20/extensions/ERC4626.sol";

import {Test} from "forge-std/Test.sol";

contract DetectSiloVaultLibTest is Test {
    /*
    FOUNDRY_PROFILE=vaults_tests \
        SILO_VAULT=<deployer_address> \
        forge test --mt test_skip_detectSiloVaultLib --ffi -vvvv

    see lib address in the traces (SiloVault will do a delegatecall to the lib)
    */
    function test_skip_detectSiloVaultLib() public {
        address vault = vm.envAddress("SILO_VAULT");
        if (vault == address(0)) return;

        vm.createSelectFork(vm.envString("RPC_SONIC"));

        ERC4626(vault).maxWithdraw(address(this));
    }
}
