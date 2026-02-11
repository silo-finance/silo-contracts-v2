// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {Test} from "forge-std/Test.sol";
import {SiloVerifier} from "silo-core/deploy/silo/verifier/SiloVerifier.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {InjectiveDeploymentHelper} from "silo-oracles/deploy/injective/InjectiveDeploymentHelper.sol";

/*
FOUNDRY_PROFILE=core CONFIG=0x6f67e4e421feedC5Bc6404790f8a5DfF456D2347 \
    EXTERNAL_PRICE_0=1 EXTERNAL_PRICE_1=1 \
    forge script silo-core/deploy/silo/VerifySilo.s.sol \
    --ffi --rpc-url $RPC_INJECTIVE
 */
contract VerifySilo is Script, Test {
    function run() public {        
        if (ChainsLib.getChainId() == ChainsLib.INJECTIVE_CHAIN_ID) {
            InjectiveDeploymentHelper injectiveHelper = new InjectiveDeploymentHelper();
            injectiveHelper.mockBankModule();
        }

        AddrLib.init();

        return;

        emit log_named_address("VerifySilo", vm.envAddress("CONFIG"));

        SiloVerifier verifier = new SiloVerifier({
            _siloConfig: ISiloConfig(vm.envAddress("CONFIG")),
            _logDetails: true,
            _externalPrice0: vm.envUint("EXTERNAL_PRICE_0"),
            _externalPrice1: vm.envUint("EXTERNAL_PRICE_1")
        });

        verifier.verify();
    }
}
