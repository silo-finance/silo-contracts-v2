// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {SiloIncentivesController} from "../../contracts/SiloIncentivesController.sol";
import {RewardToken} from "../helpers/RewardToken.sol";
import {SiloTmpVault} from "../helpers/SiloTmpVault.sol";

/*
forge test -vv --mc SiloIncentivesControllerTest
*/
contract SiloIncentivesControllerTest is Test {
    RewardToken immutable REWARD_TOKEN; // solhint-disable-line var-name-mixedcase
    SiloTmpVault immutable VAULT; // solhint-disable-line var-name-mixedcase
    SiloIncentivesController immutable SIC; // solhint-disable-line var-name-mixedcase

    address immutable user1;
    address immutable user2;

    uint256 clockStart;

    // rewards setup
    address[] assets;
    uint256[] emissionsPerSecond;

    uint256 trackRewardsSum;

    constructor() {
        user1 = makeAddr("User1");
        user2 = makeAddr("User2");

        REWARD_TOKEN = new RewardToken();
        VAULT = new SiloTmpVault();

        SIC = new SiloIncentivesController(REWARD_TOKEN, address(this));

        VAULT.setNotificationReceiver(SIC);

        assets.push(address(VAULT));
        emissionsPerSecond.push(1e18);
    }

    // forge test --gas-price 1 -vv --mt test_SiloIncentivesController_handleAction_for_to
    function test_SiloIncentivesController_handleAction_for_to() public {
        REWARD_TOKEN.mint(address(SIC), 20e18);
        SIC.configureAssets(assets, emissionsPerSecond);
        clockStart = block.timestamp;

        VAULT.deposit(100e18, user1);

        SIC.setDistributionEnd(clockStart + 20);

        _printUsersRewards(10, emissionsPerSecond[0]);

        vm.prank(user1);
        VAULT.transfer(user2, 100e18);

        _printUsersRewards(10, emissionsPerSecond[0]);

        _claim();

        assertEq(REWARD_TOKEN.balanceOf(user1), 10e18, "invalid user1 balance");
        assertEq(REWARD_TOKEN.balanceOf(user2), 10e18, "invalid user2 balance");
    }

    // forge test --gas-price 1 -vv --mt test_SiloIncentivesController_decrease_rewards
    function test_SiloIncentivesController_decrease_rewards() public {
        VAULT.setNotificationReceiver(SIC);

        REWARD_TOKEN.mint(address(SIC), 11e18);
        SIC.configureAssets(assets, emissionsPerSecond);
        clockStart = block.timestamp;

        VAULT.deposit(100e18, user1);
        SIC.setDistributionEnd(clockStart + 20);

        _printUsersRewards(10, emissionsPerSecond[0]);

        emissionsPerSecond[0] /= 10;
        SIC.configureAssets(assets, emissionsPerSecond);
        VAULT.deposit(100e18, user2);

        _printUsersRewards(10, emissionsPerSecond[0]);
        _claim();

        assertEq(REWARD_TOKEN.balanceOf(user1), 105e17, "invalid user1 balance");
        assertEq(REWARD_TOKEN.balanceOf(user2), 5e17, "invalid user2 balance");
    }

    // forge test --gas-price 1 -vv --mt test_flow
    function test_flow() public {
        _info("no rewards setup yet, but users already have some deposits and VIRTUAL rewards will be calculated for them based on shares");
        _info("user1 deposit 100 tokens before setup");
        VAULT.deposit(100e18, user1);

        _info("time before setup rewards does not matter, it will not affect VIRTUAL rewards amount");
        _jumpSec(30);

        _info("we have to setup notification receiver");
        VAULT.setNotificationReceiver(SIC);

        assertEq(SIC.getRewardsBalance(assets, user1), 0, "no rewards yet");
        assertEq(SIC.getRewardsBalance(assets, user2), 0, "no rewards yet");

        _info("minting 40 tokens as rewards.");
        REWARD_TOKEN.mint(address(SIC), 40e18);

        _info("SETUP REWARD DISTRIBUTION");
        _info("emissionsPerSecond=1e18, this is per sec per totalSupply, reward is constant, it will split among shares");
        _info("distribution `clock` starts when we call `configureAssets`, starting now.");
        SIC.configureAssets(assets, emissionsPerSecond);
        clockStart = block.timestamp;

        assertEq(SIC.getRewardsBalance(assets, user1), 0, "no rewards yet, we just started");
        assertEq(SIC.getRewardsBalance(assets, user2), 0, "no rewards yet, we just started");

        _printUsersRewards(1, emissionsPerSecond[0]);
        _info("reward is 0 because there is empty `distributionEnd` time, we have to setup this as well");

        SIC.setDistributionEnd(clockStart + 10);

        _printUsersRewards(0, emissionsPerSecond[0]);
        assertEq(SIC.getRewardsBalance(assets, user1), 1e18, "1sec of rewards gives 1 token");
        assertEq(SIC.getRewardsBalance(assets, user2), 0, "no rewards for user2");

        _info("user2 deposit 100 tokens,");
        VAULT.deposit(100e18, user2);

        _printUsersRewards(0, emissionsPerSecond[0]);

        _printUsersRewards(9, emissionsPerSecond[0]);

        assertEq(SIC.getRewardsBalance(assets, user1), 5.5e18, "user1 - first round");
        assertEq(SIC.getRewardsBalance(assets, user2), 4.5e18, "user2 - first round");

        _info("'restart' for next 10sec");
        SIC.setDistributionEnd(block.timestamp + 10);
        _printUsersRewards(10, emissionsPerSecond[0]);

        _info("when distribution Ends, no more rewards will be distributed:");
        _printUsersRewards(10, 0);

        assertEq(SIC.getRewardsBalance(assets, user1), 5.5e18 + 5e18, "user1 - 2nd round");
        assertEq(SIC.getRewardsBalance(assets, user2), 4.5e18 + 5e18, "user2 - 2nd round");

        _info("changing rewards emission to 2/s and restart for next 10sec");
        emissionsPerSecond[0] = 2e18;

        SIC.configureAssets(assets, emissionsPerSecond);
        SIC.setDistributionEnd(block.timestamp + 10);

        _info("for gap between DistributionEnd and restart, rewards should NOT be distributed");
        _printUsersRewards(0, emissionsPerSecond[0]);

        assertEq(SIC.getRewardsBalance(assets, user1), 5.5e18 + 5e18, "user1 - 2nd round, no changes");
        assertEq(SIC.getRewardsBalance(assets, user2), 4.5e18 + 5e18, "user2 - 2nd round, no changes");

        _info("when user2 withdraw 50%, automatic checkpoint is applied and rewards are calculated");
        vm.prank(user2);
        VAULT.withdraw(50e18);
        _printUsersRewards(0, emissionsPerSecond[0]);

        _info("user2 claimRewards");
        vm.prank(user2);
        SIC.claimRewards(assets, type(uint256).max, user2);
        _printUsersRewards(0, emissionsPerSecond[0]);

        assertEq(REWARD_TOKEN.balanceOf(user2), 9.5e18, "user2 claimed rewards");
        assertEq(SIC.getRewardsBalance(assets, user2), 0, "user2 claimed");

        _info("user2 withdraws all whats left");
        vm.prank(user2);
        VAULT.withdraw(50e18);
        _printUsersRewards(0, emissionsPerSecond[0]);

        _info("user1 transfers 50 tokens to user 2 (testing if we need to handleAction for address _to)");
        vm.prank(user1);
        VAULT.transfer(user2, 50e18);
        _printUsersRewards(0, emissionsPerSecond[0]);
        _printUsersRewards(5, emissionsPerSecond[0]);

        assertEq(SIC.getRewardsBalance(assets, user2), 5e18, "user2 should get 5 tokens as reward after 5sec (2/sec)");

        _info("claimRewards");
        _claim();

        assertEq(REWARD_TOKEN.balanceOf(user1), 10.5e18 + 5e18, "user1 claimed rewards");
        assertEq(REWARD_TOKEN.balanceOf(user2), 9.5e18 + 5e18, "user2 claimed rewards");
        assertEq(SIC.getRewardsBalance(assets, user1), 0, "user1 claimed");
        assertEq(SIC.getRewardsBalance(assets, user2), 0, "user2 claimed");

        vm.prank(user1);
        VAULT.withdraw(50e18);

        _printUsersRewards(0, 0);

        emit log_named_decimal_uint("user1 reward balance", REWARD_TOKEN.balanceOf(user1), 18);
        emit log_named_decimal_uint("user2 reward balance", REWARD_TOKEN.balanceOf(user2), 18);
        emit log_named_decimal_uint("STAKE contract reward balance", REWARD_TOKEN.balanceOf(address(SIC)), 18);

        assertEq(REWARD_TOKEN.balanceOf(user1), 15.5e18, "invalid user1 balance");
        assertEq(REWARD_TOKEN.balanceOf(user2), 14.5e18, "invalid user2 balance");
        assertEq(REWARD_TOKEN.balanceOf(address(SIC)), 10e18, "invalid STAKE balance");

        _info("rescueRewards");
        SIC.rescueRewards();
        assertEq(REWARD_TOKEN.balanceOf(address(SIC)), 0, "tokens rescued");
        assertEq(REWARD_TOKEN.balanceOf(address(this)), 10e18, "managet got rescued tokens");

        _printUsersRewards(5, emissionsPerSecond[0]);
        assertEq(SIC.getRewardsBalance(assets, user1), 0, "user1 - nothing to claim");
        assertEq(SIC.getRewardsBalance(assets, user2), 10e18, "user2 - 10 unclaimable tokens");

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        vm.prank(user2);
        SIC.claimRewards(assets, type(uint256).max, user2);
    }

    function _jumpSec(uint256 _time) internal {
        emit log_named_uint("time +sec", _time);
        vm.warp(block.timestamp + _time); // total 10sec
    }

    function _info(string memory _i) internal {
        emit log(string(abi.encodePacked("\n# ", _i, "\n"))); // total 10sec
    }

    function _printUsersRewards(uint256 _jump, uint256 _emission) internal {
        if (_jump != 0) _jumpSec(_jump);
        if (_emission != 0) trackRewardsSum += _jump * _emission;

        emit log_named_uint("-------------------- time pass", clockStart == 0 ? 0 : block.timestamp - clockStart);

        uint256 sum = SIC.getRewardsBalance(assets, user1) + SIC.getRewardsBalance(assets, user2);

        emit log_named_decimal_uint("rewards for user1", SIC.getRewardsBalance(assets, user1), 18);
        emit log_named_decimal_uint("getUserUnclaimedRewards", SIC.getUserUnclaimedRewards(user1), 18);
        emit log_named_decimal_uint("reward user2", SIC.getRewardsBalance(assets, user2), 18);
        emit log_named_decimal_uint("getUserUnclaimedRewards", SIC.getUserUnclaimedRewards(user2), 18);

        emit log_named_decimal_uint("SUM", sum, 18);
    }

    function _claim() internal {
        vm.prank(user1);
        SIC.claimRewards(assets, type(uint256).max, user1);
        vm.prank(user2);
        SIC.claimRewards(assets, type(uint256).max, user2);
    }
}
