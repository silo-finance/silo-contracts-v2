// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";

import {ISilo} from "../interfaces/ISilo.sol";
import {IShareTokenInitializable} from "../interfaces/IShareTokenInitializable.sol";
import {ShareTokenLib} from "../lib/ShareTokenLib.sol";

abstract contract ShareTokenInitializable is IShareTokenInitializable, Initializable {
    /// @param _silo Silo address for which tokens was deployed
    function initialize(ISilo _silo, address _hookReceiver, uint24 _tokenType) external virtual initializer {
        ShareTokenLib.__ShareToken_init(_silo, _hookReceiver, _tokenType);
    }
}
