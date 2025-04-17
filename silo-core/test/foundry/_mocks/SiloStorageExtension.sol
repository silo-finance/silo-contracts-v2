// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {SiloStorageLib} from "silo-core/contracts/lib/SiloStorageLib.sol";

contract SiloStorageExtension {
    function siloStorageMutation(ISilo.AssetType _assetType, uint256 _value) external {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();
        $.totalAssets[_assetType] = _value;
    }
}
