// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Permissioned Handler contracts
import {PublicAllocatorPermissionedHandler} from "./handlers/permissioned/PublicAllocatorPermissionedHandler.t.sol";
import {SiloVaultPermissionedHandler} from "./handlers/permissioned/SiloVaultPermissionedHandler.t.sol";

// User Handler contracts,
import {PublicAllocatorHandler} from "./handlers/user/PublicAllocatorHandler.t.sol";
import {SiloVaultHandler} from "./handlers/user/SiloVaultHandler.t.sol";

// Silo Core Handler contracts
import {SiloHandler} from "./handlers/silo-core/SiloHandler.t.sol";

// Standard Handler contracts
import {ERC20Handler} from "./handlers/standard/ERC20Handler.t.sol";
import {ERC4626Handler} from "./handlers/standard/ERC4626Handler.t.sol";

// Simulator Handler contracts
import {DonationAttackHandler} from "./handlers/simulators/DonationAttackHandler.t.sol";

// Postcondition Handler contracts
import {ERC4626PostconditionsHandler} from "./handlers/postconditions/ERC4626PostconditionsHandler.t.sol";

/// @notice Helper contract to aggregate all handler contracts, inherited in BaseInvariants
abstract contract HandlerAggregator is
    PublicAllocatorPermissionedHandler, // Permissioned handlers
    SiloVaultPermissionedHandler,
    PublicAllocatorHandler, // User handlers
    SiloVaultHandler,
    SiloHandler,
    ERC20Handler, // Standard handlers
    ERC4626Handler,
    DonationAttackHandler, // Simulator handlers
    ERC4626PostconditionsHandler
{
    /// @notice Helper function in case any handler requires additional setup
    function _setUpHandlers() internal {}
}
