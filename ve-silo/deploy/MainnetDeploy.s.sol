// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";

import {SiloGovernorDeploy} from "./SiloGovernorDeploy.s.sol";
import {LiquidityGaugeFactoryDeploy} from "./LiquidityGaugeFactoryDeploy.s.sol";
import {GaugeControllerDeploy} from "./GaugeControllerDeploy.s.sol";
import {MainnetBalancerMinterDeploy} from "./MainnetBalancerMinterDeploy.s.sol";
import {VotingEscrowRemapperDeploy} from "./VotingEscrowRemapperDeploy.s.sol";
import {GaugeAdderDeploy} from "./GaugeAdderDeploy.s.sol";
import {StakelessGaugeCheckpointerAdaptorDeploy} from "ve-silo/deploy/StakelessGaugeCheckpointerAdaptorDeploy.s.sol";
import {FeeDistributorDeploy} from "ve-silo/deploy/FeeDistributorDeploy.s.sol";
import {SmartWalletCheckerDeploy} from "./SmartWalletCheckerDeploy.s.sol";
import {VeSiloDelegatorViaCCIPDeploy} from "ve-silo/deploy/VeSiloDelegatorViaCCIPDeploy.s.sol";
import {CCIPGaugeCheckpointerDeploy} from "ve-silo/deploy/CCIPGaugeCheckpointerDeploy.s.sol";
import {VotingEscrowDelegationProxyDeploy} from "ve-silo/deploy/VotingEscrowDelegationProxyDeploy.s.sol";

import {IExtendedOwnable} from "ve-silo/contracts/access/IExtendedOwnable.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/deploy/MainnetDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract MainnetDeploy is CommonDeploy {
    bool internal _isMainnetSimulation = false;

    function run() public {
        _deployL1();
        _deployL1ForL2();

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        address balancerTokenAdmin = getDeployedAddress(VeSiloContracts.BALANCER_TOKEN_ADMIN);
        address mainnetBalancerMinter = getDeployedAddress(VeSiloContracts.MAINNET_BALANCER_MINTER);

        IExtendedOwnable(balancerTokenAdmin).changeManager(mainnetBalancerMinter);

        vm.stopBroadcast();
    }

    function enableMainnetSimulation() public {
        _isMainnetSimulation = true;
    }

    function _deployL1() internal {
        SiloGovernorDeploy governorDeploy = new SiloGovernorDeploy();
        GaugeControllerDeploy controllerDeploy = new GaugeControllerDeploy();
        MainnetBalancerMinterDeploy minterDeploy = new MainnetBalancerMinterDeploy();
        LiquidityGaugeFactoryDeploy factoryDeploy = new LiquidityGaugeFactoryDeploy();
        GaugeAdderDeploy gaugeAdderDeploy = new GaugeAdderDeploy();
        FeeDistributorDeploy feeDistributorDeploy = new FeeDistributorDeploy();
        SmartWalletCheckerDeploy smartWalletCheckerDeploy = new SmartWalletCheckerDeploy();

        if (_isMainnetSimulation) {
            governorDeploy.veBoostDeploy().enableMainnetSimulation();
        }

        governorDeploy.run();
        controllerDeploy.run();
        minterDeploy.run();
        factoryDeploy.run();
        gaugeAdderDeploy.run();
        smartWalletCheckerDeploy.run();

        if (!_isMainnetSimulation) {
            feeDistributorDeploy.run();
        }
    }

    function _deployL1ForL2() internal {
        StakelessGaugeCheckpointerAdaptorDeploy adaptorDeploy = new StakelessGaugeCheckpointerAdaptorDeploy();
        VotingEscrowRemapperDeploy remapperDeploy = new VotingEscrowRemapperDeploy();
        VeSiloDelegatorViaCCIPDeploy veSiloDelegatorDeploy = new VeSiloDelegatorViaCCIPDeploy();
        CCIPGaugeCheckpointerDeploy ccipGaugeCheckpointerDeploy = new CCIPGaugeCheckpointerDeploy();
        VotingEscrowDelegationProxyDeploy delegationProxyDeploy = new VotingEscrowDelegationProxyDeploy();

        adaptorDeploy.run();
        remapperDeploy.run();
        veSiloDelegatorDeploy.run();
        ccipGaugeCheckpointerDeploy.run();
        delegationProxyDeploy.run();
    }
}
