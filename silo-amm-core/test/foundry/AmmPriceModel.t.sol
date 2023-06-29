// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "./helpers/PriceModel.sol";
import "../../contracts/lib/PairMath.sol";
import "../../contracts/models/AmmPriceModel.sol";
import "./data-readers/AmmPriceModelTestData.sol";

/*
    FOUNDRY_PROFILE=amm-core forge test -vv --match-contract AmmPriceModelTest
*/
contract AmmPriceModelTest is Test {
    address public constant COLLATERAL = address(123);
    uint256 public constant ONE = 1e18;
    PriceModel public immutable priceModel;
    AmmPriceModelTestData public immutable ammPriceModelTestData;

    constructor() {
        AmmPriceModel.AmmPriceConfig memory config;

        config.tSlow = 1 hours;

        config.q = 1e16;
        config.kMin = 0;

        config.vFast = 4629629629629;
        config.deltaK = 3564;

        priceModel = new PriceModel(COLLATERAL, config);
        ammPriceModelTestData = new AmmPriceModelTestData();
    }

    function test_AmmPriceModel_getAmmConfig_gas() public {
        uint256 gasStart = gasleft();
        priceModel.getAmmConfig();
        uint256 gasEnd = gasleft();

        assertEq(gasStart - gasEnd, 3979);
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_AmmPriceModel_collateralPrice_gas
    */
    function test_AmmPriceModel_collateralPrice_gas() public {
        uint256 debtQuote = 2e18;
        uint256 k = 1e15;

        uint256 gasStart = gasleft();
        PairMath.getDebtIn(debtQuote, k);
        uint256 gasEnd = gasleft();

        assertEq(gasStart - gasEnd, 169);
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_AmmPriceModel_onSwapKchange_gas
    */
    function test_AmmPriceModel_onSwapKchange_gas() public {
        uint256 gasStart = gasleft();
        priceModel.onSwapCalculateK();
        uint256 gasEnd = gasleft();

        assertEq(gasStart - gasEnd, 5715);
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_AmmPriceModel_getDebtIn_andReverse
    */
    function test_AmmPriceModel_getDebtIn_andReverse() public {
        uint256 debtQuote = 1234e18;
        uint256 k = 1e14;

        uint256 gasStart = gasleft();
        uint256 debtIn = PairMath.getDebtIn(debtQuote, k);
        uint256 debtQuote2 = PairMath.getDebtInReverse(debtIn, k);
        uint256 gasEnd = gasleft();

        assertEq(debtQuote, debtQuote2);
        assertEq(gasStart - gasEnd, 356, "gas");
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_AmmPriceModel_ammPriceModelFlow
    */
    function test_AmmPriceModel_ammPriceModelFlow() public {
        unchecked {
            uint256 collateralPrice = 1000 * ONE;

            AmmPriceModelTestData.TestData[] memory testDatas = ammPriceModelTestData.testData();

            uint256 gasSum;
            assertEq(testDatas.length, 17, "for proper gas check, update it when add more tests");

            uint256 collateralLiquidity;

            for (uint i; i < testDatas.length; i++) {
                // emit log_named_uint("-------- i", i);
                AmmPriceModelTestData.TestData memory testData = testDatas[i];
                vm.warp(testData.time);

                uint256 gasStart = gasleft();

                if (testData.action == AmmPriceModelTestData.Action.INIT) {
                    priceModel.init();
                } else if (testData.action == AmmPriceModelTestData.Action.ADD_LIQUIDITY) {
                    priceModel.onAddingLiquidity(collateralLiquidity, testData.amount);
                } else if (testData.action == AmmPriceModelTestData.Action.SWAP) {
                    priceModel.onSwapPriceChange(uint64(priceModel.onSwapCalculateK()));
                } else if (testData.action == AmmPriceModelTestData.Action.WITHDRAW) {
                    priceModel.onWithdraw();
                } else {
                    revert("not supported");
                }

                uint256 gasEnd = gasleft();
                gasSum += (gasStart - gasEnd);

                collateralLiquidity = testData.amount;

                AmmPriceModel.AmmPriceState memory state = priceModel.getPriceState(COLLATERAL);

                assertEq(block.timestamp, testData.time, "time");
                assertEq(state.lastActionTimestamp, testData.tCur, "tCur");
                assertTrue(state.liquidityAdded == testData.al, "AL");
                assertTrue(state.swap == testData.swap, "SWAP");

                uint256 kPrecision = 1e5;
                assertEq(state.k / kPrecision, testData.k / kPrecision, "k");

                if (testData.price != 0) {
                    uint256 pricePrecision = 1e8;
                    uint256 debtIn = PairMath.getDebtIn(collateralPrice, state.k);
                    assertEq(debtIn / pricePrecision, testData.price / pricePrecision, "price");
                }
            }

            assertEq(gasSum, 57648, "make sure we gas efficient on price model actions");
        }
    }

    function test_AmmPriceModel_ammConfigVerification_InvalidTslow() public {
        AmmPriceModel.AmmPriceConfig memory config = priceModel.getAmmConfig();

        config.tSlow = uint32(7 days + 1);

        vm.expectRevert(IAmmPriceModel.INVALID_T_SLOW.selector);
        priceModel.ammConfigVerification(config);
    }

    function test_AmmPriceModel_ammConfigVerification_InvalidKmin() public {
        AmmPriceModel.AmmPriceConfig memory config = priceModel.getAmmConfig();

        config.kMin = uint64(priceModel.PRECISION() + 1);

        vm.expectRevert(IAmmPriceModel.INVALID_K_MIN.selector);
        priceModel.ammConfigVerification(config);
    }

    function test_AmmPriceModel_ammConfigVerification_InvalidQ() public {
        AmmPriceModel.AmmPriceConfig memory config = priceModel.getAmmConfig();

        config.q = uint64(priceModel.PRECISION() + 1);

        vm.expectRevert(IAmmPriceModel.INVALID_Q.selector);
        priceModel.ammConfigVerification(config);
    }

    function test_AmmPriceModel_ammConfigVerification_InvalidVfast() public {
        AmmPriceModel.AmmPriceConfig memory config = priceModel.getAmmConfig();

        config.vFast = uint64(priceModel.PRECISION() + 1);

        vm.expectRevert(IAmmPriceModel.INVALID_V_FAST.selector);
        priceModel.ammConfigVerification(config);
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vvv --match-test test_ammConfigVerification_InvalidDeltaK
    */
    function test_AmmPriceModel_ammConfigVerification_InvalidDeltaK() public {
        AmmPriceModel.AmmPriceConfig memory config = priceModel.getAmmConfig();

        config.deltaK = config.tSlow + 1;

        vm.expectRevert(IAmmPriceModel.INVALID_DELTA_K.selector);
        priceModel.ammConfigVerification(config);
    }
}
