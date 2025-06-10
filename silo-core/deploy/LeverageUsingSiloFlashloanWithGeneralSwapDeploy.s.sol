// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {AddrKey} from "common/addresses/AddrKey.sol";
import {CommonDeploy} from "./_CommonDeploy.sol";

import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";
import {LeverageUsingSiloFlashloanWithGeneralSwap} from "silo-core/contracts/leverage/LeverageUsingSiloFlashloanWithGeneralSwap.sol";
import {ISiloLens} from "silo-core/contracts/interfaces/ISiloLens.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/LeverageUsingSiloFlashloanWithGeneralSwapDeploy.s.sol \
        --ffi --rpc-url $RPC_SONIC --broadcast --verify

    Resume verification:
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/LeverageUsingSiloFlashloanWithGeneralSwapDeploy.s.sol \
        --ffi --rpc-url $RPC_SONIC \
        --verify \
        --verifier blockscout --verifier-url $VERIFIER_URL_INK \
        --private-key $PRIVATE_KEY \
        --resume

    remember to run `TowerRegistration` script after deployment!
 */
contract LeverageUsingSiloFlashloanWithGeneralSwapDeploy is CommonDeploy {
    function run() public returns (LeverageUsingSiloFlashloanWithGeneralSwap leverage) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address dao = AddrLib.getAddressSafe(ChainsLib.chainAlias(), AddrKey.DAO);
        address nativeToken = _nativeToken();

        vm.startBroadcast(deployerPrivateKey);

        leverage = new LeverageUsingSiloFlashloanWithGeneralSwap(dao, nativeToken);

        vm.stopBroadcast();

        console2.log("LeverageUsingSiloFlashloanWithGeneralSwap redeployed - remember to run `TowerRegistration` script!");

        _registerDeployment(address(leverage), SiloCoreContracts.SILO_LEVERAGE_USING_SILO);
    }
}
