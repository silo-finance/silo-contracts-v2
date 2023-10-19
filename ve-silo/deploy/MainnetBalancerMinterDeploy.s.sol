// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {BalancerTokenAdmin, IBalancerToken}
    from "ve-silo/contracts/silo-tokens-minter/BalancerTokenAdmin.sol";

import {MainnetBalancerMinter, IGaugeController, IBalancerMinter, IBalancerTokenAdmin}
    from "ve-silo/contracts/silo-tokens-minter/MainnetBalancerMinter.sol";

import {IExtendedOwnable} from "ve-silo/contracts/access/IExtendedOwnable.sol";
import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/deploy/MainnetBalancerMinterDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract MainnetBalancerMinterDeploy is CommonDeploy {
    function run() public returns (IBalancerMinter minter, IBalancerTokenAdmin balancerTokenAdmin) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        balancerTokenAdmin = IBalancerTokenAdmin(
            address(
                new BalancerTokenAdmin(
                    IBalancerToken(getAddress(SILO_TOKEN))
                )
            )
        );

        address gaugeController = getDeployedAddress(VeSiloContracts.GAUGE_CONTROLLER);

        minter = IBalancerMinter(
            address(
                new MainnetBalancerMinter(balancerTokenAdmin, IGaugeController(gaugeController))
            )
        );

        vm.stopBroadcast();

        _registerDeployment(address(balancerTokenAdmin), VeSiloContracts.BALANCER_TOKEN_ADMIN);
        _registerDeployment(address(minter), VeSiloContracts.MAINNET_BALANCER_MINTER);

        _syncDeployments();
    }
}
