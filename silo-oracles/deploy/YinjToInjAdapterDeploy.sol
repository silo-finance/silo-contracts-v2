// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6;

import {CommonDeploy} from "./CommonDeploy.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {YinjToInjAdapter} from "silo-oracles/contracts/custom/yINJ/YinjToInjAdapter.sol";
import {IYInjPriceOracle} from "silo-oracles/contracts/custom/yINJ/interfaces/IYInjPriceOracle.sol";
import {SiloOraclesContracts} from "./SiloOraclesContracts.sol";

/*

FOUNDRY_PROFILE=oracles \
        forge script silo-oracles/deploy/YinjToInjAdapterDeploy.sol \
        --ffi --rpc-url $RPC_INJECTIVE --broadcast --verify \
        --verifier blockscout \
        --verifier-url $VERIFIER_URL_INJECTIVE

Resume verification:
    FOUNDRY_PROFILE=oracles \
        forge script silo-oracles/deploy/YinjToInjAdapterDeploy.sol \
        --ffi --rpc-url $RPC_INJECTIVE \
        --verify \
        --verifier blockscout \
        --verifier-url $VERIFIER_URL_INJECTIVE \
        --private-key $PRIVATE_KEY \
        --resume
 */
contract YinjToInjAdapterDeploy is CommonDeploy {
    function run() public returns (YinjToInjAdapter adapter) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        IYInjPriceOracle yinjOracle = IYInjPriceOracle(getAddress(AddrKey.YINJ_PRICE_ORACLE));

        vm.startBroadcast(deployerPrivateKey);

        adapter = new YinjToInjAdapter(yinjOracle);

        vm.stopBroadcast();

        _registerDeployment(address(adapter), SiloOraclesContracts.YINJ_TO_INJ_ADAPTER);
    }
}
