// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {console2} from "forge-std/console2.sol";

import {CommonDeploy} from "../_CommonDeploy.sol";
import {SiloIncentivesControllerCreate} from "./SiloIncentivesControllerCreate.s.sol";
import {IGaugeHookReceiver} from "silo-core/contracts/interfaces/IGaugeHookReceiver.sol";
import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

/**
    INCENTIVES_OWNER=GROWTH_MULTISIG SILO=wS_scUSD_Silo INCENTIVIZED_ASSET=scUSD \
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/incentives-controller/SiloIncentivesControllerCreateAndConfigure.s.sol \
        --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract SiloIncentivesControllerCreateAndConfigure is CommonDeploy {
    SiloIncentivesControllerCreate public createIncentivesController;

    error NotHookReceiverOwner();

    constructor() {
        createIncentivesController = new SiloIncentivesControllerCreate();
    }

    function run() public {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address deployer = vm.addr(deployerPrivateKey);

        address incentivesController = createIncentivesController.run();

        address hookReceiver = createIncentivesController.hookReceiver();
        address shareToken = createIncentivesController.incentivizedAsset();

        require(Ownable(hookReceiver).owner() == deployer, NotHookReceiverOwner());

        vm.startBroadcast(deployerPrivateKey);

        IGaugeHookReceiver(hookReceiver).setGauge(ISiloIncentivesController(incentivesController), IShareToken(shareToken));

        vm.stopBroadcast();

        // hook receiver ownership acceptance data
        console2.log("\nHook receiver ownership acceptance data");
        console2.log("HookReceiver:", hookReceiver);
        console2.log("Data: ", vm.toString(abi.encodePacked(Ownable2Step.acceptOwnership.selector)));
    }
}
