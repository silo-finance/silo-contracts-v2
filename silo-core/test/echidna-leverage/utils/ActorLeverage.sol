// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20R} from "silo-core/contracts/interfaces/IERC20R.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {Actor} from "silo-core/test/invariants/utils/Actor.sol";
import {LeverageRouter} from "silo-core/contracts/leverage/LeverageRouter.sol";

/// @notice Proxy contract for invariant suite actors to avoid aTester calling contracts
contract ActorLeverage is Actor {
    constructor(address[] memory _tokens, address[] memory _contracts) payable Actor(_tokens, _contracts) {
        for (uint256 i = 0; i < _tokens.length; i++) {
            for (uint256 j = 0; j < _contracts.length; j++) {
                try LeverageRouter(_contracts[j]).predictUserLeverageContract(address(this)) returns (
                    address userLeverage
                ) {
                    IERC20(_tokens[i]).approve(userLeverage, type(uint256).max);
                    // revoke approval for router, leverage only needs approval on cloned contract
                    IERC20(_tokens[i]).approve(_contracts[j], 0);

                    try IERC20R(_tokens[i]).setReceiveApproval(userLeverage, type(uint256).max) {
                        // nothing to do
                    } catch {
                        // it might be not debt share token, ignore fail
                    }
                } catch {
                    // this is not LeverageRouter, ignore fail
                }
            }
        }
    }
}
