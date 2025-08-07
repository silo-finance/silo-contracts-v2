// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {ISilo} from "./ISilo.sol";

interface IFirmVault is IERC4626 {
    event Initialized(address indexed _initialOwner, ISilo indexed _firmSilo);

    /// @dev Initializes the firm vault
    /// @param _initialOwner The initial owner of the firm vault
    /// @param _firmSilo The firm silo to use for the firm vault
    function initialize(address _initialOwner, ISilo _firmSilo) external;
}
