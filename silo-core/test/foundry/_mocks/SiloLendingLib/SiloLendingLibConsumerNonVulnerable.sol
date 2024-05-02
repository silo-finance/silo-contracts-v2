// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloLendingLib} from "silo-core/contracts/lib/SiloLendingLib.sol";
import {AssetTypes} from "silo-core/contracts/lib/AssetTypes.sol";

contract SiloLendingLibConsumerNonVulnerable {
    uint256 public constant INITIAL_TOTAL = 100;

    mapping(uint256 assetType => ISilo.Assets) internal _total;

    constructor() {
        _total[AssetTypes.Debt].assets = INITIAL_TOTAL;
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
            _repayer,
            _total[AssetTypes.Debt]
        );
    }

    function getTotalDebt() public view returns (uint256) {
        return _total[AssetTypes.Debt].assets;
    }
}
