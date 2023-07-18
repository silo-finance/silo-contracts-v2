// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";

import {SiloGovernorDeploy} from "./SiloGovernorDeploy.s.sol";
import {LiquidityGaugeFactoryDeploy} from "./LiquidityGaugeFactoryDeploy.s.sol";
import {GaugeControllerDeploy} from "./GaugeControllerDeploy.s.sol";
import {MainnetBalancerMinterDeploy} from "./MainnetBalancerMinterDeploy.s.sol";
import {VotingEscrowRemapperDeploy} from "./VotingEscrowRemapperDeploy.s.sol";

import {IExtendedOwnable} from "ve-silo/contracts/access/IExtendedOwnable.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/deploy/MainnetDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract MainnetDeploy is CommonDeploy {
    function run() public {
        SiloGovernorDeploy governorDeploy = new SiloGovernorDeploy();
        GaugeControllerDeploy controllerDeploy = new GaugeControllerDeploy();
        MainnetBalancerMinterDeploy minterDeploy = new MainnetBalancerMinterDeploy();
        LiquidityGaugeFactoryDeploy factoryDeploy = new LiquidityGaugeFactoryDeploy();
        VotingEscrowRemapperDeploy remapperDeploy = new VotingEscrowRemapperDeploy();

        governorDeploy.run();
        controllerDeploy.run();
        minterDeploy.run();
        factoryDeploy.run();
        remapperDeploy.run();

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        address balancerTokenAdmin = getDeployedAddress(VeSiloContracts.BALANCER_TOKEN_ADMIN);
        address mainnetBalancerMinter = getDeployedAddress(VeSiloContracts.MAINNET_BALANCER_MINTER);

        IExtendedOwnable(balancerTokenAdmin).changeManager(mainnetBalancerMinter);

        vm.stopBroadcast();
    }
}
