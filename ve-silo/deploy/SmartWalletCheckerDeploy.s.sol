// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";

import {ISmartWalletChecker} from "balancer-labs/v2-interfaces/liquidity-mining/ISmartWalletChecker.sol";

import {SmartWalletChecker} from "ve-silo/contracts/voting-escrow/SmartWalletChecker.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/deploy/SmartWalletCheckerDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract SmartWalletCheckerDeploy is CommonDeploy {
    function run() public returns (ISmartWalletChecker smartWalletChecker) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        address[] memory initialAllowedAddresses;

        smartWalletChecker = ISmartWalletChecker(address(
            new SmartWalletChecker(initialAllowedAddresses)
        ));

        vm.stopBroadcast();

        _registerDeployment(address(smartWalletChecker), VeSiloContracts.SMART_WALLET_CHECKER);
        _syncDeployments();
    }
}
