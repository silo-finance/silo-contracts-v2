// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ShareCollateralBaseToken} from "./share-token/ShareCollateralBaseToken.sol";

contract ShareProtectedCollateralToken is ShareCollateralBaseToken {
    constructor() ShareCollateralBaseToken(false /* _isSiloVaultToken */) {}
}
