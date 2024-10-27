// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloLendingLib} from "silo-core/contracts/lib/SiloLendingLib.sol";
import {SiloStorageLib} from "silo-core/contracts/lib/SiloStorageLib.sol";

contract SiloLendingLibConsumerNonVulnerable {
    uint256 public constant INITIAL_TOTAL = 100;

    constructor() {
        SiloStorageLib.getSiloStorage().totalAssets[ISilo.AssetType.Debt] = INITIAL_TOTAL;
    }

    function repay(
        ISiloConfig.ConfigData memory _configData,
        uint256 _assets,
        uint256 _shares,
        address _borrower,
        address _repayer
    ) external {
        SiloLendingLib.repay(
            IShareToken(_configData.debtShareToken),
            _configData.token,
            _assets,
            _shares,
            _borrower,
            _repayer
        );
    }

    function getTotalDebt() public view returns (uint256) {
        return SiloStorageLib.getSiloStorage().totalAssets[ISilo.AssetType.Debt];
    }
}
