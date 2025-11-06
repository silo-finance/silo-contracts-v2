// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {IIncentivesClaimingLogic} from "../interfaces/IIncentivesClaimingLogic.sol";

contract BorrowFromSilo is IIncentivesClaimingLogic {
    ISilo internal constant SILO = ISilo(0xf0543D476e7906374863091034fe679a7bE8Ee20);

    function claimRewardsAndDistribute() external {
        SILO.borrow({
            _assets: 1e6,
            _receiver: address(this),
            _borrower: address(this)
        });
    }
}
