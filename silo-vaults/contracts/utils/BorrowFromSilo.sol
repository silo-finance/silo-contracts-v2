// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {IIncentivesClaimingLogic} from "../interfaces/IIncentivesClaimingLogic.sol";

contract BorrowFromSilo is IIncentivesClaimingLogic {
    ISilo internal constant SILO = ISilo(0xf0543D476e7906374863091034fe679a7bE8Ee20);

    function claimRewardsAndDistribute() external {
        uint256 maxBorrow = SILO.maxBorrow(address(this));

        require(maxBorrow != 0, "maxBorrow is 0");

        SILO.borrow({
            _assets: maxBorrow,
            _receiver: address(this),
            _borrower: address(this)
        });
    }
}
