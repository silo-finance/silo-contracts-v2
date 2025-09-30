// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICheck} from "silo-core/deploy/silo/verifier/checks/ICheck.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";
import {Utils} from "silo-core/deploy/silo/verifier/Utils.sol";

contract CheckPTLinearOracle is ICheck {
    address internal ptLinearAggregator;
    address internal asset;

    constructor(address _oracle, address _asset) {
        asset = _asset;

        (
            address primaryAggregator, address secondaryAggregator
        ) = Utils.tryGetChainlinkAggregators(_oracle);

        if (Utils.tryGetPT(primaryAggregator) != address(0)) {
            ptLinearAggregator = primaryAggregator;
            return;
        }

        if (Utils.tryGetPT(secondaryAggregator) != address(0)) {
            ptLinearAggregator = secondaryAggregator;
        }
    }

    function checkName() external pure override returns (string memory name) {
        name = "PT linear aggregator's PT token is equal to Silo's PT token";
    }

    /// @dev automatically true if it is NOT PT Linear aggregator
    function successMessage() external view override returns (string memory message) {
        message = ptLinearAggregator != address(0)
            ? "PT() token from aggregator is equal to Silo asset"
            : "aggregator is NOT PT linear aggregator";
    }

    /// @dev false only when it is PT Linear aggregator and asset does not match with PT
    function errorMessage() external pure override returns (string memory message) {
        message = "PT() token from aggregator is NOT equal to Silo asset";
    }

    function execute() external view override returns (bool result) {
        result = ptLinearAggregator == address(0) || Utils.tryGetPT(ptLinearAggregator) == asset;
    }
}
