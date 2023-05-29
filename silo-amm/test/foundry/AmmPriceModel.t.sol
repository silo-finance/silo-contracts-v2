// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../contracts/AmmPriceModel.sol";
import "./data-readers/AmmPriceModelTestData.sol";

/*
    FOUNDRY_PROFILE=amm forge test -vvv --match-contract AmmPriceModelTest
*/
contract AmmPriceModelTest is Test {
    uint256 public constant ONE = 1e18;
    AmmPriceModel public immutable priceModel;
    AmmPriceModelTestData public immutable ammPriceModelTestData;

    constructor() {
        AmmPriceModel.AmmPriceConfig memory config;

        config.tSlow = 1 hours;

        config.q = 1e16;
        config.kMax = 1e18;
        config.kMin = 0;

        config.vFast = 4629629629629;
        config.deltaK = 3564;

        priceModel = new AmmPriceModel(config);
        ammPriceModelTestData = new AmmPriceModelTestData();
    }

    function test_getAmmConfig_gas() public {
        uint256 gasStart = gasleft();
        priceModel.getAmmConfig();
        uint256 gasEnd = gasleft();

        assertEq(gasStart - gasEnd, 4067);
    }

    function test_collateralPrice_gas() public {
        uint256 gasStart = gasleft();
        priceModel.collateralPrice(1, 2);
        uint256 gasEnd = gasleft();

        assertEq(gasStart - gasEnd, 5574);
    }

    /*
        FOUNDRY_PROFILE=amm forge test -vvv --match-test test_ammPriceModelFlow
    */
    function test_ammPriceModelFlow() public {
        unchecked {
            uint256 twap = 1000 * ONE;

            AmmPriceModelTestData.TestData[] memory testDatas = ammPriceModelTestData.testData();

            uint256 gasSum;
            assertEq(testDatas.length, 17, "for proper gas check, update it when add more tests");

            for (uint i; i < testDatas.length; i++) {
                AmmPriceModelTestData.TestData memory testData = testDatas[i];
                vm.warp(testData.time);

                uint256 gasStart = gasleft();

                if (testData.action == AmmPriceModelTestData.Action.INIT) {
                    priceModel.init();
                } else if (testData.action == AmmPriceModelTestData.Action.ADD_LIQUIDITY) {
                    priceModel.onAddingLiquidity();
                } else if (testData.action == AmmPriceModelTestData.Action.SWAP) {
                    priceModel.onSwap();
                } else if (testData.action == AmmPriceModelTestData.Action.WITHDRAW) {
                    priceModel.onWithdraw();
                } else {
                    revert("not supported");
                }

                uint256 gasEnd = gasleft();
                gasSum += (gasStart - gasEnd);

                AmmPriceModel.AmmPriceState memory state = priceModel.getState();

                assertEq(block.timestamp, testData.time, "time");
                assertEq(state.lastActionTimestamp, testData.tCur, "tCur");
                assertTrue(state.liquidityAdded == testData.al, "AL");
                assertTrue(state.swap == testData.swap, "SWAP");

                int256 kPrecision = 1e5;
                assertEq(state.k / kPrecision, testData.k / kPrecision, "k");

                if (testData.price != 0) {
                    uint256 pricePrecision = 1e8;
                    uint256 price = priceModel.collateralPrice(ONE, twap);
                    assertEq(price / pricePrecision, testData.price / pricePrecision, "price");
                }
            }

            assertEq(gasSum, 44774, "make sure we gas efficient on price model actions");
        }
    }

    function test_ammConfigVerification_InvalidTslow() public {
        AmmPriceModel.AmmPriceConfig memory config = priceModel.getAmmConfig();

        config.tSlow = -1;

        vm.expectRevert(AmmPriceModel.InvalidTslow.selector);
        priceModel.ammConfigVerification(config);

        config.tSlow = int32(7 days + 1);

        vm.expectRevert(AmmPriceModel.InvalidTslow.selector);
        priceModel.ammConfigVerification(config);
    }

    function test_ammConfigVerification_InvalidKmax() public {
        AmmPriceModel.AmmPriceConfig memory config = priceModel.getAmmConfig();

        config.kMax = 0;

        vm.expectRevert(AmmPriceModel.InvalidKmax.selector);
        priceModel.ammConfigVerification(config);

        config.kMax = int64(priceModel.ONE() + 1);

        vm.expectRevert(AmmPriceModel.InvalidKmax.selector);
        priceModel.ammConfigVerification(config);
    }

    function test_ammConfigVerification_InvalidKmin() public {
        AmmPriceModel.AmmPriceConfig memory config = priceModel.getAmmConfig();

        config.kMin = -1;

        vm.expectRevert(AmmPriceModel.InvalidKmin.selector);
        priceModel.ammConfigVerification(config);

        config.kMin = int64(config.kMax + 1);

        vm.expectRevert(AmmPriceModel.InvalidKmin.selector);
        priceModel.ammConfigVerification(config);
    }

    function test_ammConfigVerification_InvalidQ() public {
        AmmPriceModel.AmmPriceConfig memory config = priceModel.getAmmConfig();

        config.q = -1;

        vm.expectRevert(AmmPriceModel.InvalidQ.selector);
        priceModel.ammConfigVerification(config);

        config.q = int64(priceModel.ONE() + 1);

        vm.expectRevert(AmmPriceModel.InvalidQ.selector);
        priceModel.ammConfigVerification(config);
    }

    function test_ammConfigVerification_InvalidVfast() public {
        AmmPriceModel.AmmPriceConfig memory config = priceModel.getAmmConfig();

        config.vFast = -1;

        vm.expectRevert(AmmPriceModel.InvalidVfast.selector);
        priceModel.ammConfigVerification(config);

        config.vFast = int64(priceModel.ONE() + 1);

        vm.expectRevert(AmmPriceModel.InvalidVfast.selector);
        priceModel.ammConfigVerification(config);
    }

    /*
        FOUNDRY_PROFILE=amm forge test -vvv --match-test test_ammConfigVerification_InvalidDeltaK
    */
    function test_ammConfigVerification_InvalidDeltaK() public {
        AmmPriceModel.AmmPriceConfig memory config = priceModel.getAmmConfig();

        config.deltaK = -1;

        vm.expectRevert(AmmPriceModel.InvalidDeltaK.selector);
        priceModel.ammConfigVerification(config);

        config.deltaK = config.tSlow + 1;

        vm.expectRevert(AmmPriceModel.InvalidDeltaK.selector);
        priceModel.ammConfigVerification(config);
    }
}
