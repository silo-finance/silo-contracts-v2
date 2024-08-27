// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ShareCollateralToken} from "./ShareCollateralToken.sol";
import {ShareTokenInitializable} from "./ShareTokenInitializable.sol";

contract ShareProtectedCollateralToken is ShareCollateralToken, ShareTokenInitializable {}
