// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ISiloReentrancyGuard} from "./interfaces/ISiloReentrancyGuard.sol";
import {ISiloConfig} from "./interfaces/ISiloConfig.sol";

abstract contract SiloReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    error OtherSiloRequired();
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = _NOT_ENTERED;
    }

    function nonReentrantBefore() public {
        ISiloConfig siloConfig = _getSiloConfigAddr();

        address _otherSilo = siloConfig.getOtherSiloProtected(address(this));

        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        if (_status == _ENTERED || ISiloReentrancyGuard(_otherSilo).reentrancyGuardEntered()) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function nonReentrantAfter() public {
        ISiloConfig siloConfig = _getSiloConfigAddr();

        // check permissins
        siloConfig.getOtherSiloProtected(address(this));

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    function reentrancyGuardEntered() public view returns (bool) {
        return _status == _ENTERED;
    }

    function _getSiloConfigAddr() internal view virtual returns (ISiloConfig);
}
