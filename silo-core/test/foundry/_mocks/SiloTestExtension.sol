// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {SiloStorageLib} from "silo-core/contracts/lib/SiloStorageLib.sol";

contract SiloTestExtension {
    function testSiloStorageMutation(uint256 _assetType, uint256 _value) external {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();
        $.totalAssets[_assetType] = _value;
    }
}
