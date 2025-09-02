// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {SiloVerifier} from "silo-core/deploy/silo/verifier/SiloVerifier.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

/**
FOUNDRY_PROFILE=core CONFIG=0xCB2dcdC5E4016d0BE706df5e312Fb3E7c2341497 \
    EXTERNAL_PRICE_0=99999 EXTERNAL_PRICE_1=100000 \
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
            _externalPrice0: vm.envOr("EXTERNAL_PRICE_0", uint256(0)),
            _externalPrice1: vm.envOr("EXTERNAL_PRICE_1", uint256(0))
        });

        verifier.verify();
    }
}
