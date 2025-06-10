// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Import User Actions Handler contracts,
import {ShareTokenHandler} from 'silo-core/test/invariants/handlers/user/ShareTokenHandler.t.sol';
import {BorrowingHandler} from 'silo-core/test/invariants/handlers/user/BorrowingHandler.t.sol';
import {VaultHandler} from 'silo-core/test/invariants/handlers/user/VaultHandler.t.sol';
import {LiquidationHandler} from 'silo-core/test/invariants/handlers/user/LiquidationHandler.t.sol';
import {SiloHandler} from 'silo-core/test/invariants/handlers/user/SiloHandler.t.sol';

// Import Permissioned Actions Handler contracts,
import {SiloConfigHandler} from 'silo-core/test/invariants/handlers/permissioned/SiloConfigHandler.t.sol';
import {SiloFactoryHandler} from 'silo-core/test/invariants/handlers/permissioned/SiloFactoryHandler.t.sol';
import {FlashLoanHandler} from 'silo-core/test/invariants/handlers/simulators/FlashLoanHandler.t.sol';
import {MockOracleHandler} from 'silo-core/test/invariants/handlers/simulators/MockOracleHandler.t.sol';

import {LeverageHandler} from './handlers/user/LeverageHandler.t.sol';

/// @notice Helper contract to aggregate all handler contracts, inherited in BaseInvariants
abstract contract HandlerAggregatorLeverage is
  ShareTokenHandler, // User Actions
  BorrowingHandler,
  VaultHandler,
  LiquidationHandler,
  LeverageHandler,
  SiloHandler,
  SiloConfigHandler, // Permissioned Actions
  SiloFactoryHandler,
  FlashLoanHandler, // Simulators
  MockOracleHandler
{
  /// @notice Helper function in case any handler requires additional setup
  // function _setUpHandlers() internal {}
}
