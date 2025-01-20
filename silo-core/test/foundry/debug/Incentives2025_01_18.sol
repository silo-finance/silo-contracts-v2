// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Utils} from "silo-foundry-utils/lib/Utils.sol";
import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {SiloIncentivesController} from "silo-core/contracts/incentives/SiloIncentivesController.sol";
import {IDistributionManager} from "silo-core/contracts/incentives/interfaces/IDistributionManager.sol";
import {SiloIncentivesController} from "silo-core/contracts/incentives/SiloIncentivesController.sol";
import {Silo} from "silo-core/contracts/Silo.sol";
import {SiloIncentivesControllerGaugeLike} from "silo-core/contracts/incentives/SiloIncentivesControllerGaugeLike.sol";
import {DistributionTypes} from "silo-core/contracts/incentives/lib/DistributionTypes.sol";
import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";
import {IGaugeHookReceiver} from "silo-core/contracts/interfaces/IGaugeHookReceiver.sol";
import {IGaugeLike} from "silo-core/contracts/interfaces/IGaugeLike.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {
    SiloIncentivesControllerGaugeLikeFactoryDeploy
} from "silo-core/deploy/SiloIncentivesControllerGaugeLikeFactoryDeploy.sol";

import {
    ISiloIncentivesControllerGaugeLikeFactory
} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesControllerGaugeLikeFactory.sol";

// FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc Incentives20250118Test
contract Incentives20250118Test is IntegrationTest {
    SiloIncentivesController internal _controller = SiloIncentivesController(0x31bFB77eF861d9273658d5e943a7BF2E2c8B0b7f);
    Silo internal _silo = Silo(payable(0x4E216C15697C1392fE59e1014B009505E05810Df));
    address internal _rewardToken = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38;
    address internal _whale = 0xE223C8e92AA91e966CA31d5C6590fF7167E25801;
    address internal _usdc = 0x29219dd400f2Bf60E5a23d13Be72B486D4038894;
    address internal _usdcWhale = 0x4E216C15697C1392fE59e1014B009505E05810Df;
    string internal constant _PROGRAM_NAME = "wS_sUSDC_007";

    /*
    FOUNDRY_PROFILE=core-test forge test -vv --ffi --mt test_user_0x84d0F74d21a89F86b67e9a38d8559d0b4e10F12d
    */
    function test_user_0x84d0F74d21a89F86b67e9a38d8559d0b4e10F12d() public {
        uint256[] memory claimBlocks = new uint256[](10);

        address _user = 0x84d0F74d21a89F86b67e9a38d8559d0b4e10F12d;

        claimBlocks[0] = 4321417; // https://sonicscan.org/tx/0x5b0d9ece436b5dab4f9afe62cbe72a541156b983b6bd4a3f6560db92bd2e1cda
        claimBlocks[1] = 4304791; // https://sonicscan.org/tx/0xdd12fba380e4d07ba83854b28c0043103dfd78de28271412aa755d3ca70e92df
        claimBlocks[2] = 4305229; // https://sonicscan.org/tx/0x1758b425cbaab79e2e4131e827273d90b24c5c3390e0128e48730143df6a8f82
        claimBlocks[3] = 4305493; // https://sonicscan.org/tx/0x78ba3ab524a0cfcc97390bca14d6ddd0b2be048fd3fb6dc6ac6a052eb7bf6aef
        claimBlocks[4] = 4305711; // https://sonicscan.org/tx/0x8fc820484978287bcff244fddb65e237a08d84546debb84104df7ae1cb9fe62c
        claimBlocks[5] = 4305815; // https://sonicscan.org/tx/0xbff63b9bbe1567dbd4d4afa1e9e550e71edf3ffbe2c63cdd100b0cdad33c1386
        claimBlocks[6] = 4306103; // https://sonicscan.org/tx/0x94bc03d82c9c7716ec8799a214627d14e91aad78998349bba3ae66575ac9e7e6
        claimBlocks[7] = 4307602; // https://sonicscan.org/tx/0xe00dda68392e8ba4c224e103bffd2764f62650f620595d402b5e2b66cf4a5964
        claimBlocks[8] = 4321418; // https://sonicscan.org/tx/0xf2c829512853d381502743e0c927526abe805f9d1995f6487dcf9ab9ebbbbe5c
        claimBlocks[9] = 4357665; // last block;

        for (uint256 i = 0; i < claimBlocks.length; i++) {
            uint256 blockToFork = claimBlocks[i] - 1;
            vm.createSelectFork(vm.envString("RPC_SONIC"), blockToFork);

            emit log_named_uint("\n block", claimBlocks[i]);

            uint256 siloTotalSupply = _silo.totalSupply();
            uint256 siloBalance = _silo.balanceOf(_user);
            uint256 rewardsBalance = _controller.getRewardsBalance(_user, _PROGRAM_NAME);
            uint256 userIndex = _controller.getUserData(_user, _PROGRAM_NAME);
            uint256 userUnclaimedRewards = _controller.getUserUnclaimedRewards(_user, _PROGRAM_NAME);

            IDistributionManager.IncentiveProgramDetails memory details = _controller.incentivesProgram(_PROGRAM_NAME);

            uint256 reserveIndex = _getIncentivesProgramIndex(
                details.index,
                details.emissionPerSecond,
                details.lastUpdateTimestamp,
                details.distributionEnd,
                siloTotalSupply
            );

            emit log_named_uint("details.index", details.index);
            emit log_named_uint("reserveIndex", reserveIndex);
            emit log_named_uint("userIndex", userIndex);
            emit log_named_uint("details.emissionPerSecond", details.emissionPerSecond);
            emit log_named_uint("details.lastUpdateTimestamp", details.lastUpdateTimestamp);
            emit log_named_uint("block.timestamp", block.timestamp);
            emit log_named_uint("details.distributionEnd", details.distributionEnd);

            uint256 expectedRewards = _getRewards(siloBalance, reserveIndex, userIndex) + userUnclaimedRewards;

            emit log_named_uint("silo.totalSupply()", siloTotalSupply);
            emit log_named_uint("silo.balanceOf(_user)", siloBalance);
            emit log_named_uint("rewardsBalance", rewardsBalance);
            emit log_named_uint("userUnclaimedRewards", userUnclaimedRewards);
            emit log_named_uint("expectedRewards", expectedRewards);
        }
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vv --ffi --mt test_user_0x56f2C4CB8518d0a4Ec749593dF574f7597A36140
    */
    function test_user_0x56f2C4CB8518d0a4Ec749593dF574f7597A36140() public {
        uint256[] memory claimBlocks = new uint256[](4);

        address _user = 0x56f2C4CB8518d0a4Ec749593dF574f7597A36140;

        claimBlocks[0] = 4306097; // https://sonicscan.org/tx/0x1bcfa9e648ecdf88302f9a49fea448fad55093674dd107d5551acbc8d2581ae7
        claimBlocks[1] = 4306175; // https://sonicscan.org/tx/0xc2e302190298d4878d1f3bc465e5335c5baaa1976ad4c71f88552be96c5fc945
        claimBlocks[2] = 4306264; // https://sonicscan.org/tx/0x1e0e313f9b9ecf7121a116970a5e40544fcce9e70244b768962db24b291480b5
        claimBlocks[3] = 4357665; // last block;

        for (uint256 i = 0; i < claimBlocks.length; i++) {
            uint256 blockToFork = claimBlocks[i] - 1;
            vm.createSelectFork(vm.envString("RPC_SONIC"), blockToFork);

            emit log_named_uint("\n block", claimBlocks[i]);

            uint256 siloTotalSupply = _silo.totalSupply();
            uint256 siloBalance = _silo.balanceOf(_user);
            uint256 rewardsBalance = _controller.getRewardsBalance(_user, _PROGRAM_NAME);
            uint256 userIndex = _controller.getUserData(_user, _PROGRAM_NAME);
            uint256 userUnclaimedRewards = _controller.getUserUnclaimedRewards(_user, _PROGRAM_NAME);

            IDistributionManager.IncentiveProgramDetails memory details = _controller.incentivesProgram(_PROGRAM_NAME);

            uint256 reserveIndex = _getIncentivesProgramIndex(
                details.index,
                details.emissionPerSecond,
                details.lastUpdateTimestamp,
                details.distributionEnd,
                siloTotalSupply
            );

            emit log_named_uint("details.index", details.index);
            emit log_named_uint("reserveIndex", reserveIndex);
            emit log_named_uint("userIndex", userIndex);
            emit log_named_uint("details.emissionPerSecond", details.emissionPerSecond);
            emit log_named_uint("details.lastUpdateTimestamp", details.lastUpdateTimestamp);
            emit log_named_uint("block.timestamp", block.timestamp);
            emit log_named_uint("details.distributionEnd", details.distributionEnd);

            uint256 expectedRewards = _getRewards(siloBalance, reserveIndex, userIndex);

            emit log_named_uint("silo.totalSupply()", siloTotalSupply);
            emit log_named_uint("silo.balanceOf(_user)", siloBalance);
            emit log_named_uint("rewardsBalance", rewardsBalance);
            emit log_named_uint("userUnclaimedRewards", userUnclaimedRewards);
            emit log_named_uint("expectedRewards", expectedRewards);
        }
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vv --ffi --mt test_code_replacement

    uint256 blockToFork = 4321258;
    address _user = 0xB214dc646Ff531c61911F78389f5E49C2087991e;
    */
    function test_code_replacement() public {
        uint256 blockToFork = 4306097;
        vm.createSelectFork(vm.envString("RPC_SONIC"), blockToFork);

        address _user = 0x56f2C4CB8518d0a4Ec749593dF574f7597A36140;

        vm.prank(_user);
        _controller.claimRewards(_user);

        uint256 rewardsBalance = _controller.getRewardsBalance(_user, _PROGRAM_NAME);
        uint256 userUnclaimedRewards = _controller.getUserUnclaimedRewards(_user, _PROGRAM_NAME);

        emit log_named_uint("rewardsBalance no fix", rewardsBalance);
        emit log_named_uint("userUnclaimedRewards no fix", userUnclaimedRewards);

        SiloIncentivesController controller = new SiloIncentivesControllerGaugeLike(
            address(_silo),
            address(_silo),
            address(_silo)
        );

        bytes memory code = Utils.getCodeAt(address(controller));

        vm.etch(address(_controller), code);

        vm.prank(_user);
        _controller.claimRewards(_user);

        userUnclaimedRewards = _controller.getUserUnclaimedRewards(_user, _PROGRAM_NAME);
        rewardsBalance = _controller.getRewardsBalance(_user, _PROGRAM_NAME);

        emit log_named_uint("rewardsBalance fixed", rewardsBalance);
        emit log_named_uint("userUnclaimedRewards fixed", userUnclaimedRewards);

        vm.warp(block.timestamp + 10);

        rewardsBalance = _controller.getRewardsBalance(_user, _PROGRAM_NAME);
        emit log_named_uint("rewardsBalance after 10 seconds", rewardsBalance);

        IDistributionManager.IncentiveProgramDetails memory details = _controller.incentivesProgram(_PROGRAM_NAME);

        vm.prank(_user);
        IDistributionManager.AccruedRewards[] memory accruedRewards = _controller.claimRewards(_user);

        rewardsBalance = _controller.getRewardsBalance(_user, _PROGRAM_NAME);

        emit log_named_uint("accruedRewards[0].amount", accruedRewards[0].amount);
        emit log_named_uint("rewardsBalance after claim", rewardsBalance);
        emit log_named_uint("details.index", details.index);
        emit log_named_uint("details.emissionPerSecond", details.emissionPerSecond);
        emit log_named_uint("details.lastUpdateTimestamp", details.lastUpdateTimestamp);
        emit log_named_uint("block.timestamp", block.timestamp);
        emit log_named_uint("details.distributionEnd", details.distributionEnd);

        uint256 siloTotalSupply = _silo.totalSupply();
        uint256 siloBalance = _silo.balanceOf(_user);

        uint256 expectedEmission = details.emissionPerSecond * 10 * siloBalance / siloTotalSupply;
        emit log_named_uint("expectedEmission", expectedEmission);

        assertEq(
            accruedRewards[0].amount,
            expectedEmission,
            "expectedEmission should be equal to accruedRewards[0].amount"
        );
    }

    // FOUNDRY_PROFILE=core-test forge test -vv --ffi --mt test_one_more_scenario
    function test_one_more_scenario() public {
        uint256 blockToFork = 4406293; // Jan-18-2025 02:11:29 PM +UTC
        vm.createSelectFork(vm.envString("RPC_SONIC"), blockToFork);

        SiloIncentivesControllerGaugeLikeFactoryDeploy deploy = new SiloIncentivesControllerGaugeLikeFactoryDeploy();
        deploy.disableDeploymentsSync();

        ISiloIncentivesControllerGaugeLikeFactory factory = deploy.run();

        address owner = 0x4d62b6E166767988106cF7Ee8fE23E480E76FF1d;
        address notifier = 0xB01e62Ba9BEc9Cfa24b2Ee321392b8Ce726D2A09;
        address shareToken = address(_silo);

        _controller = SiloIncentivesController(
            address(factory.createGaugeLike(owner, notifier, shareToken))
        );

        // Configuring gauge hook receiver
        vm.prank(owner);
        IGaugeHookReceiver(notifier).setGauge(IGaugeLike(address(_controller)), IShareToken(shareToken));

        // Create incentives program
        uint256 programDuration = 6 days;

        uint40 distributionEnd = uint40(block.timestamp + programDuration);
        uint104 emissionPerSecond = 0.001e18;

        uint256 rewardAmount = emissionPerSecond * programDuration;

        vm.prank(owner);
        _controller.createIncentivesProgram(DistributionTypes.IncentivesProgramCreationInput({
            name: _PROGRAM_NAME,
            rewardToken: _rewardToken,
            distributionEnd: distributionEnd,
            emissionPerSecond: emissionPerSecond
        }));

        // Transfer rewards to the controller
        vm.prank(_whale);
        IERC20(_rewardToken).transfer(address(_controller), rewardAmount);

        emit log_string("Check rewards of the previous user at the start of the program");

        address user1 = 0x56f2C4CB8518d0a4Ec749593dF574f7597A36140;
        uint256 rewardsBalance = _controller.getRewardsBalance(user1, _PROGRAM_NAME);
        emit log_named_address("user1", user1);
        emit log_named_uint("rewardsBalance", rewardsBalance);
        assertEq(rewardsBalance, 0, "rewardsBalance should be 0");

        address user2 = 0xB214dc646Ff531c61911F78389f5E49C2087991e;
        rewardsBalance = _controller.getRewardsBalance(user2, _PROGRAM_NAME);
        emit log_named_address("user2", user2);
        emit log_named_uint("rewardsBalance", rewardsBalance);
        assertEq(rewardsBalance, 0, "rewardsBalance should be 0");

        emit log_string("Move time forward block.timestamp + 1 days");
        uint256 timeDelta = 1 days;
        vm.warp(block.timestamp + timeDelta);

        emit log_string("\n Check rewards for user1");

        _getRewardsNoIndex(user1, timeDelta, emissionPerSecond);

        emit log_string("\n Check rewards for user2");

        _getRewardsNoIndex(user2, timeDelta, emissionPerSecond);

        emit log_string("\n New user depositing into the silo");
        address user3 = makeAddr("User3");
        uint256 depositAmount = 100e6;
        // Transfer token to the user
        vm.prank(_usdcWhale);
        IERC20(_usdc).transfer(user3, depositAmount);

        // Deposit token to the silo
        vm.prank(user3);
        IERC20(_usdc).approve(address(_silo), type(uint256).max);
        vm.prank(user3);
        _silo.deposit(depositAmount, user3);

        emit log_string("\n Check rewards for user3");

        _getRewardsNoIndex(user3, 0, emissionPerSecond);

        emit log_string("\n Move time forward block.timestamp + 1 days");
        uint256 moveTime = 1 days;
        vm.warp(block.timestamp + moveTime);

        timeDelta += moveTime;

        emit log_string("\n Check rewards for user1");

        _getRewardWithIndex(user1);

        emit log_string("\n Check rewards for user2");

        _getRewardWithIndex(user2);

        emit log_string("\n Check rewards for user3");

        _getRewardWithIndex(user3);

        emit log_string("\n Move time forward block.timestamp + 1 days");

        uint256 balanceBefore = IERC20(_rewardToken).balanceOf(address(user1));

        vm.prank(user1);
        IDistributionManager.AccruedRewards[] memory accruedRewards = _controller.claimRewards(user1);

        uint256 balanceAfter = IERC20(_rewardToken).balanceOf(address(user1));

        assertEq(
            accruedRewards[0].amount,
            balanceAfter - balanceBefore,
            "accruedRewards[0].amount should be equal to balance"
        );

        vm.warp(block.timestamp + 1 days);

        emit log_string("\n Check rewards for user1");

        _getRewardsNoIndex(user1, 1 days, emissionPerSecond);

        balanceBefore = IERC20(_rewardToken).balanceOf(address(user1));

        vm.prank(user1);
        accruedRewards = _controller.claimRewards(user1);

        balanceAfter = IERC20(_rewardToken).balanceOf(address(user1));

        assertEq(
            accruedRewards[0].amount,
            balanceAfter - balanceBefore,
            "accruedRewards[0].amount should be equal to balance"
        );

        _getRewardsNoIndex(user1, 0, emissionPerSecond);

        rewardsBalance = _controller.getRewardsBalance(user3, _PROGRAM_NAME);

        // Transfer token to the user
        vm.prank(_usdcWhale);
        IERC20(_usdc).transfer(user3, depositAmount);

        // Deposit token to the silo
        vm.prank(user3);
        IERC20(_usdc).approve(address(_silo), type(uint256).max);
        vm.prank(user3);
        _silo.deposit(depositAmount, user3);

        uint256 userUnclaimedRewards = _controller.getUserUnclaimedRewards(user3, _PROGRAM_NAME);
        emit log_named_uint("userUnclaimedRewards", userUnclaimedRewards);

        assertNotEq(userUnclaimedRewards, 0, "userUnclaimedRewards should be greater than 0");

        balanceBefore = IERC20(_rewardToken).balanceOf(address(user3));

        vm.prank(user3);
        accruedRewards = _controller.claimRewards(user3);

        balanceAfter = IERC20(_rewardToken).balanceOf(address(user3));

        assertEq(
            accruedRewards[0].amount,
            balanceAfter - balanceBefore,
            "accruedRewards[0].amount should be equal to balance"
        );

        assertEq(
            rewardsBalance,
            accruedRewards[0].amount,
            "rewardsBalance should be equal to accruedRewards[0].amount"
        );
    }

    function _getRewardWithIndex(address _user) internal returns (uint256 expectedRewards) {
        uint256 userIndex = _controller.getUserData(_user, _PROGRAM_NAME);
        IDistributionManager.IncentiveProgramDetails memory details = _controller.incentivesProgram(_PROGRAM_NAME);
        uint256 siloBalance = _silo.balanceOf(_user);
        uint256 siloTotalSupply = _silo.totalSupply();
        uint256 rewardsBalance = _controller.getRewardsBalance(_user, _PROGRAM_NAME);

        uint256 reserveIndex = _getIncentivesProgramIndex(
            details.index,
            details.emissionPerSecond,
            details.lastUpdateTimestamp,
            details.distributionEnd,
            siloTotalSupply
        );

        expectedRewards = _getRewards(siloBalance, reserveIndex, userIndex);

        emit log_named_uint("rewardsBalance", rewardsBalance);
        emit log_named_uint("expectedRewards", expectedRewards);

        assertEq(rewardsBalance, expectedRewards, "rewardsBalance should be equal to expectedRewards");
    }

    function _getRewardsNoIndex(
        address _user,
        uint256 _timeDelta,
        uint256 _emissionPerSecond
    ) internal returns (uint256 expectedRewards) {
        uint256 siloBalance = _silo.balanceOf(_user);
        uint256 siloTotalSupply = _silo.totalSupply();
        uint256 rewardsBalance = _controller.getRewardsBalance(_user, _PROGRAM_NAME);
        emit log_named_uint("emissionPerSecond", _emissionPerSecond);
        emit log_named_uint("siloBalance", siloBalance);
        emit log_named_uint("siloTotalSupply", siloTotalSupply);
        emit log_named_uint("rewardsBalance", rewardsBalance);

        expectedRewards = _emissionPerSecond * _timeDelta * siloBalance / siloTotalSupply;
        emit log_named_uint("expectedRewards", expectedRewards);

        assertEq(rewardsBalance, expectedRewards, "rewardsBalance should be equal to expectedRewards");
    }

    function _getRewards(
        uint256 principalUserBalance,
        uint256 reserveIndex,
        uint256 userIndex
    ) internal pure virtual returns (uint256 rewards) {
        rewards = principalUserBalance * (reserveIndex - userIndex);
        unchecked { rewards /= 10 ** 18; }
    }

    function _getIncentivesProgramIndex(
        uint256 currentIndex,
        uint256 emissionPerSecond,
        uint256 lastUpdateTimestamp,
        uint256 distributionEnd,
        uint256 totalBalance
    ) internal view virtual returns (uint256 newIndex) {
        if (
            emissionPerSecond == 0 ||
            totalBalance == 0 ||
            lastUpdateTimestamp == block.timestamp ||
            lastUpdateTimestamp >= distributionEnd
        ) {
            return currentIndex;
        }

        uint256 currentTimestamp = block.timestamp > distributionEnd ? distributionEnd : block.timestamp;
        uint256 timeDelta = currentTimestamp - lastUpdateTimestamp;

        newIndex = emissionPerSecond * timeDelta * 10 ** 18;
        unchecked { newIndex /= totalBalance; }
        newIndex += currentIndex;
    }
}
