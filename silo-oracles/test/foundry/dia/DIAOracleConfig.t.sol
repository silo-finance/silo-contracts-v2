// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.18;

import "../../../constants/Arbitrum.sol";

import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {TokensGenerator} from "../_common/TokensGenerator.sol";
import {DIAOracle, DIAOracle, IDIAOracle, IDIAOracleV2} from "../../../contracts/dia/DIAOracle.sol";
import {DIAOracleConfig} from "../../../contracts/dia/DIAOracleConfig.sol";
import "../_common/DIAConfigDefault.sol";

/*
    FOUNDRY_PROFILE=oracles forge test -vv --match-contract DIAOracleConfigTest
*/
contract DIAOracleConfigTest is DIAConfigDefault {
    uint256 constant TEST_BLOCK = 124937740;

    DIAOracleConfig public immutable CFG;

    constructor() TokensGenerator(BlockChain.ARBITRUM) {
        initFork(TEST_BLOCK);

        CFG = new DIAOracleConfig(_defaultDIAConfig(), false, 10 ** (18 + 8 - 18), 0, "RDPX/USD");
    }

    function test_DIAOracleConfig_getQuoteData() public {
        IDIAOracle.DIASetup memory setup = CFG.getSetup();

        assertEq(address(setup.diaOracle), address(DIA_ORACLE_V2), "diaOracle");
        assertEq(setup.baseToken, address(tokens["RDPX"]), "baseToken");
        assertEq(setup.quoteToken, address(tokens["USDT"]), "quoteToken");
        assertEq(uint256(setup.heartbeat), uint256(1 days), "heartbeat");
        assertEq(uint256(setup.normalizationDivider), 100000000, "normalizationDivider");
        assertEq(uint256(setup.normalizationMultiplier), 0, "normalizationMultiplier");
        assertFalse(setup.quoteIsEth, "quoteIsEth");
        assertEq(setup.key, "RDPX/USD", "key");
    }
}
