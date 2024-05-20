// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {SiloStorage} from "silo-core/contracts/SiloStorage.sol";

contract SiloTestExtension is SiloStorage {
    function testSiloStorageMutation(uint256 _assetType, uint256 _value) external {
        _total[_assetType].assets = _value;
    }
}
