// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

/// @dev This is cloned solution of @openzeppelin/contracts/security/ReentrancyGuard.sol
abstract contract LeverageReentrancyGuard is Initializable {
    uint256 private constant _LEVERAGE_NOT_ENTERED = 1;
    uint256 private constant _LEVERAGE_ENTERED = 2;

    uint256 private _leverageStatus;

    error LeverageReentrancyCall();

    modifier leverageNonReentrant() {
        if (_leverageStatus == _LEVERAGE_ENTERED) {
            revert LeverageReentrancyCall();
        }

        _leverageStatus = _LEVERAGE_ENTERED;

        _;

        _leverageStatus = _LEVERAGE_NOT_ENTERED;
    }

    function __LeverageReentrancyGuard_init() internal virtual onlyInitializing {
        // solhint-disable-previous-line func-name-mixedcase
        _leverageStatus = _LEVERAGE_NOT_ENTERED;
    }
}
