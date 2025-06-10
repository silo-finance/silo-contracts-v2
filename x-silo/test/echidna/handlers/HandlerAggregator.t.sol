// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Import User Actions Handler contracts,
import {ShareTokenHandler} from './user/ShareTokenHandler.t.sol';
import {VaultHandler} from './user/VaultHandler.t.sol';
import {XSiloHandler} from './user/XSiloHandler.t.sol';

// Import Permissioned Actions Handler contracts,
import {XSiloConfigHandler} from './permissioned/XSiloConfigHandler.t.sol';
import {StreamHandler} from './permissioned/StreamHandler.t.sol';

/// @notice Helper contract to aggregate all handler contracts, inherited in BaseInvariants
abstract contract HandlerAggregator is
  ShareTokenHandler, // User Actions
  VaultHandler
//  XSiloHandler,
//  XSiloConfigHandler, // Permissioned Actions
//  StreamHandler - do not include here, it has separate Test contract
{
  /// @notice Helper function in case any handler requires additional setup
  function _setUpHandlers() internal {}
}
