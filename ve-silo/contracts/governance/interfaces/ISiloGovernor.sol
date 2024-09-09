// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IGovernor} from "openzeppelin5/governance/IGovernor.sol";
import {IVeSilo} from "ve-silo/contracts/voting-escrow/interfaces/IVeSilo.sol";

interface ISiloGovernor is IGovernor {
    function veSiloToken() external view returns (IVeSilo);
}
