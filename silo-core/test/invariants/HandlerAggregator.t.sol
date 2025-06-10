// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Import User Actions Handler contracts,
import {ShareTokenHandler} from './handlers/user/ShareTokenHandler.t.sol';
import {BorrowingHandler} from './handlers/user/BorrowingHandler.t.sol';
import {VaultHandler} from './handlers/user/VaultHandler.t.sol';
import {LiquidationHandler} from './handlers/user/LiquidationHandler.t.sol';
import {SiloHandler} from './handlers/user/SiloHandler.t.sol';

// Import Permissioned Actions Handler contracts,
import {SiloConfigHandler} from './handlers/permissioned/SiloConfigHandler.t.sol';
import {SiloFactoryHandler} from './handlers/permissioned/SiloFactoryHandler.t.sol';
import {FlashLoanHandler} from './handlers/simulators/FlashLoanHandler.t.sol';
import {MockOracleHandler} from './handlers/simulators/MockOracleHandler.t.sol';

/// @notice Helper contract to aggregate all handler contracts, inherited in BaseInvariants
abstract contract HandlerAggregator is
  ShareTokenHandler, // User Actions
  BorrowingHandler,
  VaultHandler,
  LiquidationHandler,
  SiloHandler,
  SiloConfigHandler, // Permissioned Actions
  SiloFactoryHandler,
  FlashLoanHandler, // Simulators
  MockOracleHandler
{
  /// @notice Helper function in case any handler requires additional setup
  function _setUpHandlers() internal {}
}
