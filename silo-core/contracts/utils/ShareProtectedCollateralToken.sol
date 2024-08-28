// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ShareCollateralToken} from "./ShareCollateralToken.sol";
import {ISilo} from "../interfaces/ISilo.sol";
import {IShareTokenInitializable} from "../interfaces/IShareTokenInitializable.sol";

contract ShareProtectedCollateralToken is ShareCollateralToken, IShareTokenInitializable {
    /// @inheritdoc IShareTokenInitializable
    function initialize(ISilo _silo, address _hookReceiver, uint24 _tokenType) external virtual {
        _shareTokenInitialize(_silo, _hookReceiver, _tokenType);
    }
}
