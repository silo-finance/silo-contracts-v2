// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

/// @title IIdleVaultsFactory
/// @dev Forked with gratitude from Morpho Labs.
/// @author Silo Labs
/// @custom:contact security@silo.finance
/// @notice Interface of IdleVault's factory.
interface IIdleVaultsFactory {
    /// @notice Whether a IdleVault vault was created with the factory.
    function isIdleVault(address _target) external view returns (bool);

    /// @notice Creates a new IdleVault.
    /// @param _vault vault address for which idle vault will be created
    function createIdleVault(IERC4626 _vault) external returns (IERC4626 idleVault);
}
