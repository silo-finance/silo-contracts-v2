// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "silo-core/contracts/lib/SiloStdLib.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {SiloConfigMock} from "../../_mocks/SiloConfigMock.sol";
import {InterestRateModelMock} from "../../_mocks/InterestRateModelMock.sol";
import {TokenMock} from "../../_mocks/TokenMock.sol";

/*
forge test -vv --mc FlashFeeTest
*/
contract FlashFeeTest is Test {
    struct FeeTestCase {
        uint256 flashloanFeeInBp;
        uint256 amount;
        uint256 fee;
    }

    SiloConfigMock immutable SILO_CONFIG;

    uint256 daoFeeInBp;
    uint256 deployerFeeInBp;

    mapping(uint256 => FeeTestCase) public feeTestCases;
    uint256 feeTestCasesIndex;

    constructor() {
        SILO_CONFIG = new SiloConfigMock(address(1));
    }

    /*
    forge test -vv --mt test_flashFee
    */
    function test_flashFee(address _silo, address _asset) public {
        vm.assume(_silo != address(0));
        vm.assume(_asset != address(0));

        ISiloConfig siloConfig = ISiloConfig(SILO_CONFIG.ADDRESS());

        feeTestCases[feeTestCasesIndex++] = FeeTestCase({flashloanFeeInBp: 0.1e4, amount: 1e18, fee: 0.1e18});
        feeTestCases[feeTestCasesIndex++] = FeeTestCase({flashloanFeeInBp: 0, amount: 1e18, fee: 0});
        feeTestCases[feeTestCasesIndex++] = FeeTestCase({flashloanFeeInBp: 0.1e4, amount: 0, fee: 0});
        feeTestCases[feeTestCasesIndex++] = FeeTestCase({flashloanFeeInBp: 0, amount: 0, fee: 0});
        feeTestCases[feeTestCasesIndex++] = FeeTestCase({flashloanFeeInBp: 0.125e4, amount: 1e18, fee: 0.125e18});
        feeTestCases[feeTestCasesIndex++] = FeeTestCase({flashloanFeeInBp: 0.65e4, amount: 1e18, fee: 0.65e18});

        for (uint256 index = 0; index < feeTestCasesIndex; index++) {
            SILO_CONFIG.getFeesWithAsset(address(this), 0, 0, feeTestCases[index].flashloanFeeInBp, _asset);

            assertEq(SiloStdLib.flashFee(siloConfig, _asset, feeTestCases[index].amount), feeTestCases[index].fee);
        }
    }
}
