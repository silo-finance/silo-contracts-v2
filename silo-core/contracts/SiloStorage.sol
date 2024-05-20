// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

contract SiloStorage {
    ISilo.SiloData internal _siloData;

    ISilo.SharedStorage internal _sharedStorage;

    /// @dev silo is just for one asset, but this one asset can be of three types: mapping key is uint256(AssetType),
    /// so we store `assets` by type.
    /// We are useing struct `Assets` instead of direct uint256 to pass storage reference to functions.
    /// `total` can have outdated value (without interest), if you doing view call (of off-chain call) please use
    /// getters eg `getCollateralAssets()` to fetch value that includes interest.
    mapping(uint256 assetType => ISilo.Assets) internal _total;
}
