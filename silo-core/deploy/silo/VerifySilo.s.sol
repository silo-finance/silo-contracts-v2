// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {SiloVerifier} from "silo-core/deploy/silo/verifier/SiloVerifier.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

/*
FOUNDRY_PROFILE=core CONFIG=0xB37Ec4a417C2540B2c353aE4a7D9cBC576f702ea \
    EXTERNAL_PRICE_0=10658 EXTERNAL_PRICE_1=100000 \
    forge script silo-core/deploy/silo/VerifySilo.s.sol \
    --ffi --rpc-url $RPC_SONIC
 */
contract VerifySilo is Script, Test {
    function run() public {
        AddrLib.init();

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
