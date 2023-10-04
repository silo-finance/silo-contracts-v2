// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IBalancerMinter} from "@silo/silo-contracts-v2/ve-silo/contracts/silo-tokens-minter/interfaces/IBalancerMinter.sol";

abstract contract HarvestManager is Ownable {
    address public constant SILO = 0x6f80310CA7F2C654691D1383149Fa1A57d8AB1f8;
    IBalancerMinter public balancerMinter;

    function _setBalancerMinter(address _balancerMinter) internal {
        balancerMinter = IBalancerMinter(_balancerMinter);
    }

    function harvest() public {
        _harvestRewards();
    }

    function _harvestRewards() internal {
        ERC20 siloReward = ERC20(SILO);
        uint256 siloBalanceBefore = siloReward.balanceOf(address(this));

        for (uint256 i = 0; i < silos.length; i++) {
            if (gauge[silos[i]] != address(0)) {
                balancerMinter.mintFor(gauge[silos[i]], address(this));
            }
        }
        _accrueRewards(siloReward, siloReward.balanceOf(address(this)) - siloBalanceBefore);

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            ERC20 reward = rewardTokens[i];
            if (reward == ERC20(SILO)) continue;
            RewardInfo memory rewards = rewardInfos[reward];
            uint256 balanceBefore = reward.balanceOf(address(this));
            rewards.gauge.claim_rewards(address(this), address(this));
            _accrueRewards(reward, reward.balanceOf(address(this)) - balanceBefore);
        }
    }

    function reallocateManual(uint256[] memory proposed) public onlyOwner {
        _reallocate(proposed);
    }

    function reallocateWithSolver() public {
        _reallocate(_solveDistribution(_nav()));
    }

    function _reallocate(uint256[] memory proposed) internal {
        for (uint256 i = 0; i < silos.length; i++) {
            uint256 current = _getSiloDeposit(silos[i]);

            if (current > proposed[i]) {
                uint256 amount = current - proposed[i];
                _withdrawFromSilo(silos[i], amount);
            }
        }

        uint256 remaining = totalAssets();

        for (uint256 i = 0; i < silos.length; i++) {
            uint256 amountToDeposit = proposed[i] - _getSiloDeposit(silos[i]);

            if (amountToDeposit > 0) {
                _depositToSilo(silos[i], Math.min(remaining, amountToDeposit));
                remaining -= amountToDeposit;
            }

            if (remaining == 0) {
                break;
            }
        }
    }

    function _solveDistribution(uint256 _total) internal returns (uint256[] memory) {
        (int256[] memory uopt, int256[] memory ucrit) = _getConfig();
        return SolverLib.solver(_getBorrowAmounts(), _getDepositAmounts(), uopt, ucrit, _total);
    }
}
