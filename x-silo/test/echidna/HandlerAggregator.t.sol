// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Import User Actions Handler contracts,
import {ShareTokenHandler} from './handlers/user/ShareTokenHandler.t.sol';
import {VaultHandler} from './handlers/user/VaultHandler.t.sol';
import {XSiloHandler} from './handlers/user/XSiloHandler.t.sol';

// Import Permissioned Actions Handler contracts,
import {XSiloConfigHandler} from './handlers/permissioned/XSiloConfigHandler.t.sol';
import {StreamHandler} from './handlers/permissioned/StreamHandler.t.sol';

/// @notice Helper contract to aggregate all handler contracts, inherited in BaseInvariants
abstract contract HandlerAggregator is
  ShareTokenHandler, // User Actions
  VaultHandler
//  XSiloHandler,
//  XSiloConfigHandler, // Permissioned Actions
//  StreamHandler
{
  /// @notice Helper function in case any handler requires additional setup
  function _setUpHandlers() internal {}
}
