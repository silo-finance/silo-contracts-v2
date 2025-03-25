// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";

import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";

import {ManualLiquidationHelper} from "silo-core/contracts/utils/liquidationHelper/ManualLiquidationHelper.sol";

import {CommonDeploy} from "./_CommonDeploy.sol";
import {LiquidationHelperDeploy} from "./LiquidationHelperDeploy.s.sol";

/*
    ETHERSCAN_API_KEY=$ARBISCAN_API_KEY FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/ManualLiquidationHelperDeploy.s.sol:ManualLiquidationHelperDeploy \
        --ffi --rpc-url $RPC_SONIC \
        --broadcast --verify

    NOTICE: remember to register it in Tower
*/
contract ManualLiquidationHelperDeploy is LiquidationHelperDeploy {
    function run() public override returns (address manualLiquidation) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address nativeToken = _nativeToken();
        address payable tokenReceiver = _tokenReceiver();

        console2.log("[ManualLiquidationHelperDeploy] nativeToken: ", nativeToken);
        console2.log("[ManualLiquidationHelperDeploy] tokensReceiver: ", tokenReceiver);

        vm.startBroadcast(deployerPrivateKey);

        manualLiquidation = address(new ManualLiquidationHelper(nativeToken, tokenReceiver));

        vm.stopBroadcast();

        _registerDeployment(manualLiquidation, SiloCoreContracts.MANUAL_LIQUIDATION_HELPER);
    }
}
