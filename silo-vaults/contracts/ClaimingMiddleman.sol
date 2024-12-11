// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./puzzles/ClaimingPuzzle1.sol";
import "./puzzles/ClaimingPuzzle2.sol";

/// @dev this contract address must be set in vault and must be updatable
/// @dev this contract may be reusable
/// management steps:
/// 1. add/remove puzzles
/// 2. redeploy
/// 3. update contract address in vault
contract ClaimingMiddleman_USDC_ETH_rewardSILO is ClaimingPuzzle1, ClaimingPuzzle2 {
    address constant vault = address(1);

    /// @dev this method should be called as delegatecall from vault
    function claim() external {
        ClaimingPuzzle1.claim();
        ClaimingPuzzle2.claim();
    }

    /// @dev this is solution form V2, I think it is a good human error catcher that we can use on vault side
    /// to verify address we are setting
    function ping() external pure returns (bytes32) {
        return keccak256(abi.encode("ClaimingMiddleman"));
    }

    /// @dev in case we will get some unexpected reward, this is a way to unlock them, so they do not stuck here
    /// notice: this method should go to vault as well, as vault will be doing delegatecall, but it is no harm to
    /// have it here as well, it can not create any damage
    function rescueReward(address _token) {
        _token.transfer("all balance to vault");
        vault.immediateDistribution(balance);
    }
}
