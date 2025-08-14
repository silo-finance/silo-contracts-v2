// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICheck} from "silo-core/deploy/silo/verifier/checks/ICheck.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {Utils} from "silo-core/deploy/silo/verifier/Utils.sol";

contract CheckNonBorrowableAsset is ICheck {
    ISiloConfig.ConfigData configData1;
    string token0Type;
    bool assetIsRegularAsset;

    constructor(address _token0, ISiloConfig.ConfigData memory _configData1) {
        if (Utils.isTokenERC4626(_token0)) {
            token0Type = "ERC4626";
        } else if (Utils.isTokenPT(_token0)) {
            token0Type = "PT";
        } else if (Utils.isTokenLPT(_token0)) {
            token0Type = "LPT";
        } else {
            token0Type = "regular asset";
            assetIsRegularAsset = true;
        }

        configData1 = _configData1;
    }

    function checkName() external pure override returns (string memory name) {
        name = string.concat("token0 is LPT/PT/ERC4626 -> token0 is non-borrowable");
    }

    function successMessage() external view override returns (string memory message) {
        message = string.concat("property holds for ", token0Type);
    }

    function errorMessage() external view override returns (string memory message) {
        message = string.concat("property DOES NOT hold for ", token0Type);
    }

    function execute() external view override returns (bool result) {
        if (assetIsRegularAsset) return true;

        return configData1.maxLtv == 0 && configData1.lt == 0;
    }
}
