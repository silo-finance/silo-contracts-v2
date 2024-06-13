// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {CommonDeploy} from "./_CommonDeploy.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";

import {BalancerTokenAdmin, IBalancerToken}
    from "ve-silo/contracts/silo-tokens-minter/BalancerTokenAdmin.sol";

import {MainnetBalancerMinter, IGaugeController, IBalancerMinter, IBalancerTokenAdmin}
    from "ve-silo/contracts/silo-tokens-minter/MainnetBalancerMinter.sol";

import {IExtendedOwnable} from "ve-silo/contracts/access/IExtendedOwnable.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/deploy/MainnetBalancerMinterDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract MainnetBalancerMinterDeploy is CommonDeploy {
    function run() public returns (IBalancerMinter minter, IBalancerTokenAdmin balancerTokenAdmin) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        string memory chainAlias = getChainAlias();

        address siloToken = VeSiloDeployments.get(SILO_TOKEN, chainAlias);
        address gaugeController = VeSiloDeployments.get(VeSiloContracts.GAUGE_CONTROLLER, chainAlias);
        address timelock = VeSiloDeployments.get(VeSiloContracts.TIMELOCK_CONTROLLER, chainAlias);

        vm.startBroadcast(deployerPrivateKey);

        balancerTokenAdmin = IBalancerTokenAdmin(
            address(
                new BalancerTokenAdmin(
                    IBalancerToken(siloToken)
                )
            )
        );

        minter = IBalancerMinter(
            address(
                new MainnetBalancerMinter(balancerTokenAdmin, IGaugeController(gaugeController))
            )
        );

        Ownable(address(balancerTokenAdmin)).transferOwnership(timelock);

        vm.stopBroadcast();

        _registerDeployment(address(balancerTokenAdmin), VeSiloContracts.BALANCER_TOKEN_ADMIN);
        _registerDeployment(address(minter), VeSiloContracts.MAINNET_BALANCER_MINTER);
    }
}
