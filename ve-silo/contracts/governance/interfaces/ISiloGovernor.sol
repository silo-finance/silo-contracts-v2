// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IGovernor} from "openzeppelin-contracts/governance/IGovernor.sol";
import {IGovernorTimelock} from "openzeppelin-contracts/governance/extensions/IGovernorTimelock.sol";
import {IVeSilo} from "ve-silo/contracts/voting-escrow/interfaces/IVeSilo.sol";

abstract contract ISiloGovernor is IGovernor, IGovernorTimelock {
    function oneTimeInit(IVeSilo _token) external virtual;
    function veSiloToken() external view virtual returns (IVeSilo);
}
