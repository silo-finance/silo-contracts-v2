// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {BalancerTokenAdmin, IBalancerToken}
    from "ve-silo/contracts/silo-tokens-minter/BalancerTokenAdmin.sol";

import {IL2BalancerPseudoMinter} from "ve-silo/contracts/silo-tokens-minter/interfaces/IL2BalancerPseudoMinter.sol";
import {L2BalancerPseudoMinter, IERC20} from "ve-silo/contracts/silo-tokens-minter/L2BalancerPseudoMinter.sol";

import {IExtendedOwnable} from "ve-silo/contracts/access/IExtendedOwnable.sol";
import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/deploy/L2BalancerPseudoMinterDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract L2BalancerPseudoMinterDeploy is CommonDeploy {
    function run() public returns (IL2BalancerPseudoMinter minter) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        minter = IL2BalancerPseudoMinter(
            address(
                new L2BalancerPseudoMinter(IERC20(getAddress(SILO_TOKEN)))
            )
        );

        vm.stopBroadcast();

        _registerDeployment(address(minter), VeSiloContracts.L2_BALANCER_PSEUDO_MINTER);
    }
}
