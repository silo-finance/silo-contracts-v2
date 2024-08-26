// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {AssetTypes} from "silo-core/contracts/lib/AssetTypes.sol";
import {SiloLendingLibWithReentrancyIssue} from "./SiloLendingLibWithReentrancyIssue.sol";
import {SiloStorageLib} from "silo-core/contracts/lib/SiloStorageLib.sol";

contract SiloLendingLibConsumerVulnerable {
    uint256 public constant INITIAL_TOTAL = 100;

    constructor() {
        SiloStorageLib.getSiloStorage().totalAssets[AssetTypes.DEBT] = INITIAL_TOTAL;
    }

    function repay(
        ISiloConfig.ConfigData memory _configData,
        uint256 _assets,
        uint256 _shares,
        address _borrower,
        address _repayer
    ) external {
        SiloLendingLibWithReentrancyIssue.repay(
            _configData,
            _assets,
            _shares,
            _borrower,
            _repayer
        );
    }

    function getTotalDebt() public view returns (uint256) {
        return SiloStorageLib.getSiloStorage().totalAssets[AssetTypes.DEBT];
    }
}
