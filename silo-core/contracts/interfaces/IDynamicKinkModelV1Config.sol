// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IInterestRateModelV2} from "./IInterestRateModelV2.sol";

interface IInterestRateModelV2Config {
    function getConfig() external view returns (IInterestRateModelV2.Config memory config);
}