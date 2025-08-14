// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20R} from "silo-core/contracts/interfaces/IERC20R.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {Actor} from "silo-core/test/invariants/utils/Actor.sol";
import {LeverageRouter} from "silo-core/contracts/leverage/LeverageRouter.sol";

/// @notice Proxy contract for invariant suite actors to avoid aTester calling contracts
contract ActorLeverage is Actor {
    constructor(address[] memory _tokens, address[] memory _contracts) payable Actor(_tokens, _contracts) {}

    function initLeverageApprovals(address _debtShareToken, LeverageRouter _leverageRouter) external {
        address userLeverage = _leverageRouter.predictUserLeverageContract(address(this));
        IERC20R(_debtShareToken).setReceiveApproval(userLeverage, type(uint256).max);

        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).approve(userLeverage, type(uint256).max);
        }
    }
}
