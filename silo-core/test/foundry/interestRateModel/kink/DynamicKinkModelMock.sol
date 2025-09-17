// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DynamicKinkModel, IDynamicKinkModel} from "../../../../contracts/interestRateModel/kink/DynamicKinkModel.sol";
import {DynamicKinkModelConfig} from "../../../../contracts/interestRateModel/kink/DynamicKinkModelConfig.sol";

contract DynamicKinkModelMock is DynamicKinkModel {
    function mockState(IDynamicKinkModel.Config memory _c, int96 _k) external {
        irmConfig = new DynamicKinkModelConfig(_c);
        modelState.k = _k;
    }
}