// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IDynamicKinkModel} from "./IDynamicKinkModel.sol";

interface IDynamicKinkModelConfig {
    /// @return config returns immutable IRM configuration that is present in contract
    function getConfig() external view returns (IDynamicKinkModel.Config memory config);
}
