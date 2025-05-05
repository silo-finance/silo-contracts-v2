// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Silo} from "silo-core/contracts/Silo.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {SiloStorageLib} from "silo-core/contracts/lib/SiloStorageLib.sol";

contract SiloHarness is Silo {
    constructor(ISiloFactory _siloFactory) Silo(_siloFactory) {}

    function increaseTotalDebtAssets(uint256 _amount) public {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();
        $.totalAssets[ISilo.AssetType.Debt] += _amount;
    }

    function decreaseTotalDebtAssets(uint256 _amount) public {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();
        $.totalAssets[ISilo.AssetType.Debt] -= _amount;
    }

    function increaseTotalCollateralAssets(uint256 _amount) public {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();
        $.totalAssets[ISilo.AssetType.Collateral] += _amount;
    }

    function decreaseTotalCollateralAssets(uint256 _amount) public {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();
        $.totalAssets[ISilo.AssetType.Collateral] -= _amount;
    }
}
