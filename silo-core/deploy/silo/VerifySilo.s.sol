// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {SiloVerifier} from "silo-core/deploy/silo/verifier/SiloVerifier.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

/**
FOUNDRY_PROFILE=core CONFIG=0x60B054A05f39D5a170b3E7dB524C5BCE73Fa4634 \
    EXTERNAL_PRICE_0=101000 EXTERNAL_PRICE_1=99999 \
    forge script silo-core/deploy/silo/VerifySilo.s.sol \
    --ffi --rpc-url $RPC_MAINNET
 */

contract VerifySilo is Script, Test {
    function run() public {
        AddrLib.init();

        SiloVerifier verifier = new SiloVerifier({
            _siloConfig: ISiloConfig(vm.envAddress("CONFIG")),
            _logDetails: true,
            _externalPrice0: vm.envOr("EXTERNAL_PRICE_0", uint256(0)),
            _externalPrice1: vm.envOr("EXTERNAL_PRICE_1", uint256(0))
        });

        verifier.verify();
    }
}
