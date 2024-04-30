// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IGovernor} from "openzeppelin5/governance/IGovernor.sol";
// TODO import {IGovernorTimelock} from "openzeppelin5/governance/extensions/IGovernorTimelock.sol";

import {IVeSilo} from "ve-silo/contracts/voting-escrow/interfaces/IVeSilo.sol";

abstract contract ISiloGovernor is IGovernor {
    function veSiloToken() external view virtual returns (IVeSilo);
}
