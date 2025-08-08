// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {ISilo} from "./ISilo.sol";

interface IFirmVaultFactory {
    event NewFirmVault(IERC4626 firmVault);

    error DeployerCannotBeZero();

    /// @dev Creates a new firm vault
    /// @param _initialOwner The initial owner of the firm vault
    /// @param _firmSilo The firm silo to use for the firm vault
    /// @param _externalSalt A salt to use for the firm vault
    /// @return firmVault The new firm vault
    function create(address _initialOwner, ISilo _firmSilo, bytes32 _externalSalt) 
        external 
        returns (IERC4626 firmVault);

    /// @dev Predicts the address of a firm vault
    /// @param _externalSalt A salt to use for the firm vault
    /// @param _deployer The deployer of the firm vault, used to calculate the salt
    /// @return firmVault The predicted address of the firm vault
    function predictAddress(bytes32 _externalSalt, address _deployer)
        external
        view
        returns (address firmVault);
}
