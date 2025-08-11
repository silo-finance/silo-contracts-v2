// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {SiloVerifier} from "silo-core/deploy/silo/verifier/SiloVerifier.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {NewMarketTest} from "silo-core/deploy/silo/verifier/integration/NewMarket.sol";

/**
FOUNDRY_PROFILE=core CONFIG=0xC1F3d4F5f734d6Dc9E7D4f639EbE489Acd4542ab \
    EXTERNAL_PRICE_0=99999 EXTERNAL_PRICE_1=100000 \
    forge script silo-core/deploy/silo/VerifySilo.s.sol \
    --ffi --rpc-url $RPC_SONIC
 */

contract VerifySilo is Test {
    function run() public {
        AddrLib.init();

        address siloConfig = vm.envAddress("CONFIG");
        uint256 externalPrice0 = vm.envOr("EXTERNAL_PRICE_0", uint256(0));
        uint256 externalPrice1 = vm.envOr("EXTERNAL_PRICE_1", uint256(0));

        emit log_named_address("VerifySilo", siloConfig);

        SiloVerifier verifier = new SiloVerifier({
            _siloConfig: ISiloConfig(siloConfig),
            _logDetails: true,
            _externalPrice0: externalPrice0,
            _externalPrice1: externalPrice1
        });

        verifier.verify();
        
        // After verifier run, VM state will be changed from pure on-chain calls to integration test in fork.
        // Any on-chain state verification must be done before integration scenario execution. Integration tests
        // will be run on the current RPC fork at latest block minus few blocks to ensure finality.
        // These tests are not executed automatically as regular foundry tests. Script calls functions manually and
        // reverts if an assertion does not pass. New tests from imported contract are not executed automatically. 
        uint256 blockForIntegrationTests = vm.getBlockNumber() - 10;

        integrationScenarioTest({
            _blockToFork: blockForIntegrationTests,
            _siloConfig: siloConfig,
            _externalPrice0: externalPrice0,
            _externalPrice1: externalPrice1
        });
    }

    function integrationScenarioTest(
        uint256 _blockToFork,
        address _siloConfig,
        uint256 _externalPrice0,
        uint256 _externalPrice1
    ) internal {
        NewMarketTest newMarketTest = new NewMarketTest({
            _blockToFork: _blockToFork,
            _siloConfig: _siloConfig,
            _externalPrice0: _externalPrice0,
            _externalPrice1: _externalPrice1
        });

        newMarketTest.testBorrowSilo0ToSilo1();
        newMarketTest.testBorrowSilo1ToSilo0();
    }
}
