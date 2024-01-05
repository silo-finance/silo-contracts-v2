// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {CommonSiloIntegration} from "silo-core/test/foundry/_protocol/CommonSiloIntegration.sol";

/**
    Steps to run the test:

    1. Run Anvil './silo-core/test/scripts/anvil.sh'
    2. Run deployments './silo-core/test/scripts/mainnet-with-mocks-deployments.sh'
    3. Run test './silo-core/test/scripts/run-silo-with-mocks-test.sh'
    4. Clean deployments artifacts './silo-core/test/scripts/deployments-clean.sh'
 */
contract SiloMainnetWithMocksIntegrationTest is CommonSiloIntegration {
    function testIt() public {

    }
}
