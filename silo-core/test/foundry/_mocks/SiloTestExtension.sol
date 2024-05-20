// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

contract SiloTestExtension {
    ISilo.SiloData public siloData;
    ISilo.SharedStorage public sharedStorage;
    mapping(uint256 assetType => ISilo.Assets) public total;

    function testSiloStorageMutation(uint256 _assetType, uint256 _value) external {
        total[_assetType].assets = _value;
    }
}
