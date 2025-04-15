// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {ISiloVaultDeployer} from "silo-vaults/contracts/interfaces/ISiloVaultDeployer.sol";
import {SiloVaultsDeployerDeploy} from "silo-vaults/deploy/SiloVaultsDeployerDeploy.s.sol";
import {SiloIncentivesControllerFactoryDeploy} from "silo-core/deploy/SiloIncentivesControllerFactoryDeploy.s.sol";
import {SiloIncentivesControllerCLFactoryDeploy} from "silo-vaults/deploy/SiloIncentivesControllerCLFactoryDeploy.s.sol";
import {SiloVaultsFactoryDeploy} from "silo-vaults/deploy/SiloVaultsFactoryDeploy.s.sol";
/*
FOUNDRY_PROFILE=vaults_tests forge test --ffi --mc SiloVaultDeployerTest -vv
*/
contract SiloVaultDeployerTest is IntegrationTest {
    uint256 constant internal _BLOCK_TO_FORK = 20329560;
    address constant internal _USDC = 0x29219dd400f2Bf60E5a23d13Be72B486D4038894;

    ISiloVaultDeployer internal _deployer;

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_SONIC"), _BLOCK_TO_FORK);

        SiloIncentivesControllerFactoryDeploy factoryDeploy = new SiloIncentivesControllerFactoryDeploy();
        factoryDeploy.disableDeploymentsSync();
        factoryDeploy.run();

        SiloIncentivesControllerCLFactoryDeploy clFactoryDeploy = new SiloIncentivesControllerCLFactoryDeploy();
        clFactoryDeploy.run();

        SiloVaultsFactoryDeploy vaultsFactoryDeploy = new SiloVaultsFactoryDeploy();
        vaultsFactoryDeploy.run();

        SiloVaultsDeployerDeploy deployerDeploy = new SiloVaultsDeployerDeploy();
        _deployer = deployerDeploy.run();
    }

    /*
    FOUNDRY_PROFILE=vaults_tests forge test --ffi --mt test_SiloVaultDeployer_createSiloVault -vv
    */
    function test_SiloVaultDeployer_createSiloVault() public {
        address initialOwner = makeAddr("initialOwner");
        uint256 initialTimelock = 1 weeks;
        string memory name = "name";
        string memory symbol = "symbol";

        _deployer.createSiloVault(initialOwner, initialTimelock, _USDC, name, symbol);
    }
}