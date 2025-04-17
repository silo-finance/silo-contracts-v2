// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import "../../../constants/Arbitrum.sol";

import {Clones} from "openzeppelin5/proxy/Clones.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {TokensGenerator} from "../_common/TokensGenerator.sol";
import {DIAOracle, DIAOracle, IDIAOracle, IDIAOracleV2} from "../../../contracts/dia/DIAOracle.sol";
import {DIAOracleConfig} from "../../../contracts/dia/DIAOracleConfig.sol";
import {DIAConfigDefault} from "../_common/DIAConfigDefault.sol";


/*
    FOUNDRY_PROFILE=oracles forge test -vv --match-contract DIAOracleTest
*/
contract DIAOracleTest is DIAConfigDefault {
    uint256 constant TEST_BLOCK = 124937740;

    DIAOracle public immutable DIA_ORACLE;

    constructor() TokensGenerator(BlockChain.ARBITRUM) {
        initFork(TEST_BLOCK);

        DIAOracleConfig cfg = new DIAOracleConfig(_defaultDIAConfig(10 ** (18 + 8 - 18), 0));
        DIA_ORACLE = DIAOracle(Clones.clone(address(new DIAOracle())));
        DIA_ORACLE.initialize(cfg, _defaultDIAConfig().primaryKey, _defaultDIAConfig().secondaryKey);
    }

    function test_DIAOracle_initialize_OldPrice() public {
        DIAOracle newOracle = DIAOracle(Clones.clone(address(new DIAOracle())));
        IDIAOracle.DIADeploymentConfig memory cfg = _defaultDIAConfig(10 ** (18 + 8 - 18), 0);

        cfg.heartbeat = 1856;
        DIAOracleConfig newConfig = new DIAOracleConfig(cfg);

        newOracle.initialize(newConfig, cfg.primaryKey, cfg.secondaryKey);

        vm.expectRevert(IDIAOracle.OldPrice.selector);
        newOracle.quote(1e18, address(tokens["RDPX"]));
    }

    function test_DIAOracle_initialize_OldSecondaryPrice() public {
        DIAOracle newOracle = DIAOracle(Clones.clone(address(new DIAOracle())));
        IDIAOracle.DIADeploymentConfig memory cfg = _defaultDIAConfig(10 ** (18 + 8 - 18), 0);

        // at the block from test, price is 1856s old
        // and ETH price is 6306s old
        cfg.heartbeat = 1857;
        cfg.secondaryKey = "ETH/USD";

        DIAOracleConfig newConfig = new DIAOracleConfig(cfg);
        newOracle.initialize(newConfig, cfg.primaryKey, cfg.secondaryKey);

        vm.expectRevert(IDIAOracle.OldSecondaryPrice.selector);
        newOracle.quote(1e18, address(tokens["RDPX"]));
    }

    function test_DIAOracle_initialize_pass() public {
        DIAOracle newOracle = DIAOracle(Clones.clone(address(new DIAOracle())));
        IDIAOracle.DIADeploymentConfig memory cfg = _defaultDIAConfig(10 ** (18 + 8 - 18), 0);

        DIAOracleConfig newConfig = new DIAOracleConfig(cfg);

        newOracle.initialize(newConfig, cfg.primaryKey, cfg.secondaryKey);
    }

    /*
        FOUNDRY_PROFILE=oracles forge test -vvv --mt test_DIAOracle_quote_pass
    */
    function test_DIAOracle_quote_inUSDT() public {
        uint256 price = DIA_ORACLE.quote(1e18, address(tokens["RDPX"]));
        emit log_named_decimal_uint("RDPX/USD", price, 18);
        assertEq(price, 17889972650000000000, "$17,88");
    }

    /*
        FOUNDRY_PROFILE=oracles forge test -vvv --mt test_DIAOracle_quote_inUSDC
    */
    function test_DIAOracle_quote_inUSDC() public {
        IDIAOracle.DIADeploymentConfig memory cfg = _defaultDIAConfig();
        cfg.quoteToken = IERC20Metadata(address(tokens["USDC"]));
        DIAOracleConfig oracleConfig = new DIAOracleConfig(_defaultDIAConfig(10 ** (18 + 8 - 6), 0));
        DIAOracle oracle = DIAOracle(Clones.clone(address(new DIAOracle())));
        oracle.initialize(oracleConfig, cfg.primaryKey, cfg.secondaryKey);

        uint256 price = oracle.quote(1e18, address(tokens["RDPX"]));
        emit log_named_decimal_uint("RDPX/USD", price, 6);
        assertEq(price, 17889972, "$17,88");
    }

    /*
        FOUNDRY_PROFILE=oracles forge test -vvv --mt test_DIAOracle_quote_AssetNotSupported
    */
    function test_DIAOracle_quote_AssetNotSupported() public {
        vm.expectRevert(IDIAOracle.AssetNotSupported.selector);
        DIA_ORACLE.quote(1e18, address(1));
    }

    /*
        FOUNDRY_PROFILE=oracles forge test -vvv --mt test_DIAOracle_quote_AssetNotSupported
    */
    function test_DIAOracle_quote_BaseAmountOverflow() public {
        vm.expectRevert(IDIAOracle.BaseAmountOverflow.selector);
        DIA_ORACLE.quote(2 ** 128, address(tokens["RDPX"]));
    }

    function test_DIAOracle_quoteToken() public {
        assertEq(address(DIA_ORACLE.quoteToken()), address(tokens["USDT"]), "must be USDC");
    }
}
