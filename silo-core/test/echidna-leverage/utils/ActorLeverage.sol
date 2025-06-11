// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20R} from "silo-core/contracts/interfaces/IERC20R.sol";
import {Actor} from "silo-core/test/invariants/utils/Actor.sol";

/// @notice Proxy contract for invariant suite actors to avoid aTester calling contracts
contract ActorLeverage is Actor {

    constructor(address[] memory _tokens, address[] memory _contracts) payable Actor(_tokens, _contracts) {
        for (uint256 i = 0; i < _tokens.length; i++) {
            for (uint256 j = 0; j < _contracts.length; j++) {
                try IERC20R(_tokens[i]).setReceiveApproval(_contracts[j], type(uint256).max) {
                    // nothing to do
                } catch {
                    // it might be not debt share token, ignore fail
                }
            }
        }
    }
}
