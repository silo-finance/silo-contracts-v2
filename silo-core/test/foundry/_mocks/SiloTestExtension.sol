// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {Actions} from "silo-core/contracts/lib/Actions.sol";

contract SiloTestExtension {
    function testSiloStorageMutation(uint256 _assetType, uint256 _value) external {
        ISilo.SiloStorage storage $ = Actions._getSiloStorage();
        $._total[_assetType].assets = _value;
    }
}
