// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAggregatorInterfaceMinimal} from "./IAggregatorInterfaceMinimal.sol";

interface IWrappedMetaVaultOracle is IAggregatorInterfaceMinimal {
    function wrappedMetaVault() external view returns (address);
}
