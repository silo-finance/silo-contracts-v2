// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {
    SiloIncentivesControllerCL
} from "silo-vaults/contracts/incentives/claiming-logics/SiloIncentivesControllerCL.sol";

import {
    SiloIncentivesControllerCLFactory
} from "silo-vaults/contracts/incentives/claiming-logics/SiloIncentivesControllerCLFactory.sol";

import {
    SiloIncentivesControllerCLFactoryDeploy
} from "silo-vaults/deploy/SiloIncentivesControllerCLFactoryDeploy.s.sol";

import {
    ISiloIncentivesController,
    IDistributionManager
} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";

// FOUNDRY_PROFILE=vaults-tests forge test -vvv --ffi --mc SiloIncentivesControllerCLTest
contract SiloIncentivesControllerCLTest is Test {
    SiloIncentivesControllerCL public incentivesControllerCL;

    address internal _vaultIncentivesController = makeAddr("VaultIncentivesController");
    address internal _siloIncentivesController = makeAddr("SiloIncentivesController");

    function setUp() public {
        SiloIncentivesControllerCLFactoryDeploy factoryDeploy = new SiloIncentivesControllerCLFactoryDeploy();
        factoryDeploy.disableDeploymentsSync();
        address factory = factoryDeploy.run();

        incentivesControllerCL = SiloIncentivesControllerCLFactory(factory).createIncentivesControllerCL(
            _vaultIncentivesController,
            _siloIncentivesController
        );

        assertTrue(SiloIncentivesControllerCLFactory(factory).createdInFactory(address(incentivesControllerCL)));
    }

    // FOUNDRY_PROFILE=vaults-tests forge test -vvv --ffi --mt test_claimRewardsAndDistribute
    function test_claimRewardsAndDistribute() public {
        address rewardToken1 = makeAddr("RewardToken1");
        address rewardToken2 = makeAddr("RewardToken2");

        uint256 amount1 = 1000;
        uint256 amount2 = 2000;

        bytes memory claimRewardsInput = abi.encodeWithSignature(
            "claimRewards(address)",
            address(_vaultIncentivesController)
        );

        IDistributionManager.AccruedRewards memory accruedReward1 = IDistributionManager.AccruedRewards({
            rewardToken: rewardToken1,
            programId: bytes32(uint256(1)),
            amount: amount1
        });

        IDistributionManager.AccruedRewards memory accruedReward2 = IDistributionManager.AccruedRewards({
            rewardToken: rewardToken2,
            programId: bytes32(uint256(2)),
            amount: amount2
        });

        IDistributionManager.AccruedRewards[] memory accruedRewards = new IDistributionManager.AccruedRewards[](2);
        accruedRewards[0] = accruedReward1;
        accruedRewards[1] = accruedReward2;

        bytes memory claimRewardsReturnData = abi.encode(accruedRewards);

        vm.mockCall(_siloIncentivesController, claimRewardsInput, claimRewardsReturnData);
        vm.expectCall(_siloIncentivesController, claimRewardsInput);

        bytes memory immediateDistributionInput1 = abi.encodeWithSelector(
            ISiloIncentivesController.immediateDistribution.selector,
            rewardToken1,
            amount1
        );

        bytes memory immediateDistributionInput2 = abi.encodeWithSelector(
            ISiloIncentivesController.immediateDistribution.selector,
            rewardToken2,
            amount2
        );

        vm.mockCall(_vaultIncentivesController, immediateDistributionInput1, "0x");
        vm.mockCall(_vaultIncentivesController, immediateDistributionInput2, "0x");

        vm.expectCall(_vaultIncentivesController, immediateDistributionInput1);
        vm.expectCall(_vaultIncentivesController, immediateDistributionInput2);

        incentivesControllerCL.claimRewardsAndDistribute();
    }
}
