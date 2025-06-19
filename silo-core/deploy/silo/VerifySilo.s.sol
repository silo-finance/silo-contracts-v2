// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {SiloVerifier} from "silo-core/deploy/silo/verifier/SiloVerifier.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

/**
FOUNDRY_PROFILE=core CONFIG=0xB0F495c7705CCfD5f2A0F9485ff7e300D43F9855 \
    EXTERNAL_PRICE_0=10100 EXTERNAL_PRICE_1=9999 \
    forge script silo-core/deploy/silo/VerifySilo.s.sol \
    --ffi --rpc-url $RPC_MAINNET
 */

contract VerifySilo is Script, Test {
    function run() public {
        AddrLib.init();

        emit log("VerifySilo", vm.envAddress("CONFIG"));

        SiloVerifier verifier = new SiloVerifier({
            _siloConfig: ISiloConfig(vm.envAddress("CONFIG")),
            _logDetails: true,
            _externalPrice0: vm.envOr("EXTERNAL_PRICE_0", uint256(0)),
            _externalPrice1: vm.envOr("EXTERNAL_PRICE_1", uint256(0))
        });

        verifier.verify();
    }
}
