// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IGaugeHookReceiver} from "./IGaugeHookReceiver.sol";
import {IPartialLiquidation} from "./IPartialLiquidation.sol";

interface ISiloHookV1 is IGaugeHookReceiver, IPartialLiquidation {}
