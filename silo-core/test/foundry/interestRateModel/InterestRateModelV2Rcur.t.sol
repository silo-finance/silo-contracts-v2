// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Strings} from "openzeppelin5/utils/Strings.sol";
import {Clones} from "openzeppelin5/proxy/Clones.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {InterestRateModelV2Impl} from "./InterestRateModelV2Impl.sol";
import {InterestRateModelConfigs} from "../_common/InterestRateModelConfigs.sol";
import {RcurTestData} from "../data-readers/RcurTestData.sol";
import {IInterestRateModelV2} from "silo-core/contracts/interfaces/IInterestRateModelV2.sol";
import {IInterestRateModelV2Config} from "silo-core/contracts/interfaces/IInterestRateModelV2Config.sol";
import {InterestRateModelV2Config} from "silo-core/contracts/interestRateModel/InterestRateModelV2Config.sol";

// forge test -vv --mc InterestRateModelV2RcurTest
contract InterestRateModelV2RcurTest is RcurTestData, InterestRateModelConfigs {
    InterestRateModelV2Impl immutable INTEREST_RATE_MODEL;

    uint256 constant DP = 10 ** 18;
    uint256 constant BASIS_POINTS = 10000;

    constructor() {
        INTEREST_RATE_MODEL = new InterestRateModelV2Impl();
    }
}
