// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {IIncentivesClaimingLogic} from "../interfaces/IIncentivesClaimingLogic.sol";

contract RescueWAVAX is IIncentivesClaimingLogic {
    IERC20 internal constant WAVAX = IERC20(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);
    address public constant WAVAX_RECEIVER = 0xE8e8041cB5E3158A0829A19E014CA1cf91098554;
    
    error VaultAssetCanNotBeRescued();

    function claimRewardsAndDistribute() external {
        IERC4626 vault = IERC4626(address(this));
        require(vault.asset() != address(WAVAX), VaultAssetCanNotBeRescued());

        uint256 balance = WAVAX.balanceOf(address(this));
        if (balance == 0) return;

        try WAVAX.transfer(WAVAX_RECEIVER, balance) {
        } catch {
            // do not lock/revert tx if transfer fails for any reason
        }
    }
}
