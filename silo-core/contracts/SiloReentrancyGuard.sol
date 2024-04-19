// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ISiloReentrancyGuard} from "./interfaces/ISiloReentrancyGuard.sol";
import {ISiloConfig} from "./interfaces/ISiloConfig.sol";
import {CrossEntrancy} from "./lib/CrossEntrancy.sol";

abstract contract SiloReentrancyGuard {
    uint256 private _state;

    error OtherSiloRequired();
    error ReentrancyGuardReentrantCall();

    constructor() {
        _state = CrossEntrancy.NOT_ENTERED;
    }

    function nonReentrantBefore(uint256 _entranceFrom) public {
        ISiloConfig siloConfig = _getSiloConfig();

        uint256 currentSiloState = _state;

        address otherSilo = siloConfig.getOtherSiloProtected(address(this));
        uint256 otherSiloState = ISiloReentrancyGuard(otherSilo).reentrancyGuardState();

        bool siloIsNotEntered =
            currentSiloState == CrossEntrancy.NOT_ENTERED && otherSiloState == CrossEntrancy.NOT_ENTERED;

        // On the first call to nonReentrant, _status will be CrossEntrancy.NOT_ENTERED
        if (siloIsNotEntered) {
            _state = _entranceFrom;
            return;
        }

        if (_entranceFrom == CrossEntrancy.ENTERED_FROM_LEVERAGE) {
            // before leverage callback, we mark status
            _state = CrossEntrancy.ENTERED_FROM_LEVERAGE;
            return;
        }

        bool enteredFromLaverage =
            currentSiloState == CrossEntrancy.ENTERED_FROM_LEVERAGE || otherSiloState == CrossEntrancy.ENTERED_FROM_LEVERAGE;
        
        bool notEnteredDeposit =
            currentSiloState != CrossEntrancy.ENTERED_FROM_DEPOSIT && otherSiloState != CrossEntrancy.ENTERED_FROM_DEPOSIT;

        if (enteredFromLaverage && notEnteredDeposit && _entranceFrom == CrossEntrancy.ENTERED_FROM_DEPOSIT) {
            // on leverage, entrance from deposit is allowed, but allowance is removed
            _state = CrossEntrancy.ENTERED_FROM_DEPOSIT;
            return;
        }

        revert ReentrancyGuardReentrantCall();
    }

    function nonReentrantAfter() public {
        ISiloConfig siloConfig = _getSiloConfig();

        siloConfig.getOtherSiloProtected(address(this));

        _state = CrossEntrancy.NOT_ENTERED;
    }

    function reentrancyGuardState() public view returns (uint256) {
        return _state;
    }

    function _getSiloConfig() internal view virtual returns (ISiloConfig);
}
