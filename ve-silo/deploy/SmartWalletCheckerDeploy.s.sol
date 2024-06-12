// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {CommonDeploy} from "./_CommonDeploy.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";

import {ISmartWalletChecker} from "balancer-labs/v2-interfaces/liquidity-mining/ISmartWalletChecker.sol";

import {SmartWalletChecker} from "ve-silo/contracts/voting-escrow/SmartWalletChecker.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/deploy/SmartWalletCheckerDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract SmartWalletCheckerDeploy is CommonDeploy {
    function run() public returns (ISmartWalletChecker smartWalletChecker) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address timelock = VeSiloDeployments.get(VeSiloContracts.TIMELOCK_CONTROLLER, getChainAlias());

        vm.startBroadcast(deployerPrivateKey);

        address[] memory initialAllowedAddresses;

        smartWalletChecker = ISmartWalletChecker(address(
            new SmartWalletChecker(initialAllowedAddresses)
        ));

        Ownable(address(smartWalletChecker)).transferOwnership(timelock);

        vm.stopBroadcast();

        _registerDeployment(address(smartWalletChecker), VeSiloContracts.SMART_WALLET_CHECKER);
    }
}
