// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {SiloFixture, SiloConfigOverride} from "../_common/fixtures/SiloFixture.sol";
import {MintableToken} from "../_common/MintableToken.sol";
import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";
import "../_common/DummyOracle.sol";

/*
    forge test -vv --ffi --mc BeforeQuoteTest
*/
contract BeforeQuoteTest is SiloLittleHelper, Test {
    uint256 depositAssets = 1e18;
    uint256 borrowAmount = 0.3e18;
    uint256 withdrawAmount = 0.1e18;

    address borrower;
    address depositor;
    DummyOracle solvencyOracle0;
    ISiloConfig.ConfigData cfg0;
    ISiloConfig.ConfigData cfg1;
    DummyOracle maxLtvOracle0;

    constructor() {
        borrower = address(this);
        depositor = makeAddr("Depositor");
    }

    function setUp() public {
        token0 = new MintableToken();
        token1 = new MintableToken();
        solvencyOracle0 = new DummyOracle(1e18, address(token1));
        maxLtvOracle0 = new DummyOracle(1e18, address(token1));

        SiloConfigOverride memory overrides;
        overrides.token0 = address(token0);
        overrides.token1 = address(token1);
        overrides.solvencyOracle0 = address(solvencyOracle0);
        overrides.maxLtvOracle0 = address(maxLtvOracle0);
        overrides.configName = SiloConfigsNames.LOCAL_BEFORE_CALL;

        SiloFixture siloFixture = new SiloFixture();
        (, silo0, silo1,,) = siloFixture.deploy_local(overrides);

        (cfg0, cfg1) = silo0.config().getConfigs(address(silo0));

        assertTrue(cfg0.callBeforeQuote, "beforeQuote0 is required");
        assertFalse(cfg1.callBeforeQuote, "beforeQuote1 is NOT required");
    }

    /*
    forge test -vv --ffi --mt test_beforeQuote_borrow_token0
    */
    function test_beforeQuote_borrow_token0() public {
        _setupForBorrow0();

        // notice: we calling oracle0 with `borrowAmount` because we borrowing token0, so this is our debt token
        _expectCallsToMaxLtvOracle(borrowAmount);

        silo0.borrow(borrowAmount, borrower, borrower);
    }

    /*
    forge test -vv --ffi --mt test_beforeQuote_borrow_token1
    */
    function test_beforeQuote_borrow_token1() public {
        _setupForBorrow1();

        // notice: we calling oracle0 with `depositAssets` because we borrow token1 and depositAssets is our collateral
        _expectCallsToMaxLtvOracle(depositAssets);

        silo1.borrow(borrowAmount, borrower, borrower);
    }

    /*
    forge test -vv --ffi --mt test_beforeQuote_borrow0_withdraw1
    */
    function test_beforeQuote_borrow0_withdraw1() public {
        _setupForBorrow0();

        _expectCallsToMaxLtvOracle(borrowAmount);
        silo0.borrow(borrowAmount, borrower, borrower);

        _expectCallsToSolvencyOracle(borrowAmount);
        silo1.withdraw(withdrawAmount, borrower, borrower);
    }

    /*
    forge test -vv --ffi --mt test_beforeQuote_borrow1_withdraw0
    */
    function test_beforeQuote_borrow1_withdraw0() public {
        _setupForBorrow1();

        _expectCallsToMaxLtvOracle(depositAssets);
        silo1.borrow(borrowAmount, borrower, borrower);

        _expectCallsToSolvencyOracle(depositAssets - withdrawAmount);
        silo0.withdraw(withdrawAmount, borrower, borrower);
    }

    /*
    forge test -vv --ffi --mt test_beforeQuote_borrow0_liquidate
    */
    function test_beforeQuote_borrow0_liquidate() public {
        _setupForBorrow0();

        _expectCallsToMaxLtvOracle(borrowAmount);
        silo0.borrow(borrowAmount, borrower, borrower);

        vm.startPrank(depositor);
        vm.warp(block.timestamp + 100000 days);
        token0.mint(depositor, borrowAmount / 2);
        token0.approve(address(silo0), borrowAmount / 2);

        emit log_named_address("maxLtvOracle0", address(maxLtvOracle0));
        emit log_named_address("solvencyOracle0", address(solvencyOracle0));

        _expectCallsToSolvencyOracle(0x1bd942c37174f394000); // amount with interest

        silo0.liquidationCall(address(token1), address(token0), borrower, borrowAmount / 2, false);
    }

    function _setupForBorrow0() internal {
        _deposit(depositAssets, depositor);
        _depositForBorrow(depositAssets, borrower);
    }

    function _setupForBorrow1() internal {
        _deposit(depositAssets, borrower);
        _depositForBorrow(depositAssets, depositor);
    }

    function _expectCallsToMaxLtvOracle(uint256 _quoteAmount) internal {
        maxLtvOracle0.setExpectBeforeQuote(true);

        // we DO expect beforeQuote/quote for token0 even if we borrowing token1
        // because LTV calculations needs both values, so if we have setup for oracle0, we doing a call
        vm.expectCall(address(maxLtvOracle0), abi.encodeWithSelector(ISiloOracle.beforeQuote.selector, address(token0)));
        // notice: we calling oracle0 with `depositAssets` because we borrow token1 and depositAssets is our collateral
        vm.expectCall(address(maxLtvOracle0), abi.encodeWithSelector(ISiloOracle.quote.selector, _quoteAmount, address(token0)));
    }

    function _expectCallsToSolvencyOracle(uint256 _quoteAmount) internal {
        solvencyOracle0.setExpectBeforeQuote(true);

        // we DO expect beforeQuote/quote for token0 even if we borrowing token1
        // because LTV calculations needs both values, so if we have setup for oracle0, we doing a call
        vm.expectCall(address(solvencyOracle0), abi.encodeWithSelector(ISiloOracle.beforeQuote.selector, address(token0)));
        // notice: we calling oracle0 with `depositAssets` because we borrow token1 and depositAssets is our collateral
        vm.expectCall(address(solvencyOracle0), abi.encodeWithSelector(ISiloOracle.quote.selector, _quoteAmount, address(token0)));
    }
}
