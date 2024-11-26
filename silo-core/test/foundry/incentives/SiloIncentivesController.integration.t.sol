// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.0;

// import "../../../contracts/incentives/SiloIncentivesController.sol";
// import "../../../contracts/governance/SiloGovernanceToken.sol";
// import "../_common/Forking.sol";
// import "../interface/ISiloProtocolAddresses.sol";
// import "../factories/SiloProtocolAddressesFactory.sol";
// import "../_common/SuperSilo.sol";

// import "hardhat/console.sol";

// contract SiloIncentivesControllerTest is Forking {
//     SiloGovernanceToken immutable REWARD_TOKEN; // solhint-disable-line var-name-mixedcase
//     SiloIncentivesController immutable STAKE; // solhint-disable-line var-name-mixedcase
//     SiloIncentivesController immutable STAKE2; // solhint-disable-line var-name-mixedcase

//     SuperSilo immutable SUPER_SILO; // solhint-disable-line var-name-mixedcase
//     Whales immutable WHALES; // solhint-disable-line var-name-mixedcase
//     ISiloProtocolAddresses immutable public PROTOCOL_ADDRESSES; // solhint-disable-line var-name-mixedcase

//     address constant user1 = address(0x111);
//     address constant user2 = address(0x222);

//     ISilo immutable silo;
//     IERC20 immutable incentivesAsset;
//     SiloRepository immutable siloRepository;
//     IERC20 immutable collateralToken;

//     uint256 clockStart;

//     // rewards setup
//     address[] assets;
//     uint256[] emissionsPerSecond;

//     uint256 trackRewardsSum;

//     // forge test --gas-price 1 -vv --match-contract SiloIncentivesControllerTest
//     constructor() Forking(Chain.ETHEREUM) {
//         initFork(16648170);

//         WHALES = new Whales(FORKED_CHAIN);
//         SUPER_SILO = new SuperSilo(FORKED_CHAIN);

//         SiloProtocolAddressesFactory spaFactory = new SiloProtocolAddressesFactory(FORKED_CHAIN);
//         PROTOCOL_ADDRESSES = spaFactory.create();

//         REWARD_TOKEN = SiloGovernanceToken(0x6f80310CA7F2C654691D1383149Fa1A57d8AB1f8);
//         STAKE = new SiloIncentivesController(REWARD_TOKEN, address(this));
//         STAKE2 = new SiloIncentivesController(REWARD_TOKEN, address(this));

//         siloRepository = PROTOCOL_ADDRESSES.siloRepository();

//         incentivesAsset = WHALES.tokens("GNO");
//         silo = ISilo(siloRepository.getSilo(address(incentivesAsset)));
//         emit log_named_address("silo", address(silo));

//         address owner = siloRepository.owner();
//         cheats.prank(owner);
//         siloRepository.transferOwnership(address(this));

//         IBaseSilo.AssetStorage memory assetStorage = silo.assetStorage(address(incentivesAsset));
//         collateralToken = assetStorage.collateralToken;

//         assets.push(address(collateralToken));
//         emissionsPerSecond.push(1e18);
//     }

//     // forge test --gas-price 1 -vv --match-test test_handleAction_for_to
//     function test_handleAction_for_to() public {
//         siloRepository.setNotificationReceiver(address(silo), STAKE);

//         cheats.prank(REWARD_TOKEN.owner());
//         REWARD_TOKEN.mint(address(STAKE), 20e18);
//         STAKE.configureAssets(assets, emissionsPerSecond);
//         clockStart = block.timestamp;

//         SUPER_SILO.deposit(silo, user1, address(incentivesAsset), 100e18, false);

//         STAKE.setDistributionEnd(clockStart + 20);

//         _printUsersRewards(10, emissionsPerSecond[0]);

//         cheats.prank(user1);
//         collateralToken.transfer(user2, 100e18);

//         _printUsersRewards(10, emissionsPerSecond[0]);

//         _claim();

//         assertEq(REWARD_TOKEN.balanceOf(user1), 10e18, "invalid user1 balance");
//         assertEq(REWARD_TOKEN.balanceOf(user2), 10e18, "invalid user2 balance");
//     }

//     // forge test --gas-price 1 -vv --match-test test_decrease_rewards
//     function test_decrease_rewards() public {
//         siloRepository.setNotificationReceiver(address(silo), STAKE);

//         cheats.prank(REWARD_TOKEN.owner());
//         REWARD_TOKEN.mint(address(STAKE), 11e18);
//         STAKE.configureAssets(assets, emissionsPerSecond);
//         clockStart = block.timestamp;

//         SUPER_SILO.deposit(silo, user1, address(incentivesAsset), 100e18, false);
//         STAKE.setDistributionEnd(clockStart + 20);

//         _printUsersRewards(10, emissionsPerSecond[0]);

//         emissionsPerSecond[0] /= 10;
//         STAKE.configureAssets(assets, emissionsPerSecond);
//         SUPER_SILO.deposit(silo, user2, address(incentivesAsset), 100e18, false);

//         _printUsersRewards(10, emissionsPerSecond[0]);
//         _claim();

//         assertEq(REWARD_TOKEN.balanceOf(user1), 105e17, "invalid user1 balance");
//         assertEq(REWARD_TOKEN.balanceOf(user2), 5e17, "invalid user2 balance");
//     }

//     // forge test --gas-price 1 -vv --match-test test_setNotificationReceiver_woRewards
//     function test_setNotificationReceiver_woRewards() public {
//         siloRepository.setNotificationReceiver(address(silo), STAKE);

//         SUPER_SILO.deposit(silo, user1, address(incentivesAsset), 100e18, false);

//         assertEq(STAKE.getRewardsBalance(assets, user1), 0, "invalid user1 balance");
//     }

//     // forge test --mt test_rewards_without_disconnection -vvv
//     function test_rewards_without_disconnection() public {
//         siloRepository.setNotificationReceiver(address(silo), STAKE);

//         _info("minting 40 SILO as rewards.");
//         cheats.prank(REWARD_TOKEN.owner());
//         REWARD_TOKEN.mint(address(STAKE), 40e18);

//         STAKE.configureAssets(assets, emissionsPerSecond);
//         STAKE.setDistributionEnd(block.timestamp + 10);

//         SUPER_SILO.deposit(silo, user1, address(incentivesAsset), 100e18, false);

//         _printUsersRewards(1, emissionsPerSecond[0]);

//         SUPER_SILO.deposit(silo, user1, address(incentivesAsset), 100e18, false);

//         _printUsersRewards(1, emissionsPerSecond[0]);
//     }

//     // forge test --mt test_rewards_with_disconnection -vvv
//     function test_rewards_with_disconnection() public {
//         siloRepository.setNotificationReceiver(address(silo), STAKE);

//         cheats.prank(REWARD_TOKEN.owner());
//         REWARD_TOKEN.mint(address(STAKE), 40e18);
//         cheats.prank(REWARD_TOKEN.owner());
//         REWARD_TOKEN.mint(address(STAKE2), 40e18);

//         STAKE.configureAssets(assets, emissionsPerSecond);
//         STAKE.setDistributionEnd(block.timestamp + 10);

//         SUPER_SILO.deposit(silo, user1, address(incentivesAsset), 200e18, false);
//         SUPER_SILO.deposit(silo, user2, address(incentivesAsset), 100e18, false);

//         _jumpSec(5);

//         _printUsersRewards(1, emissionsPerSecond[0]);
//         _printUsersRewardsSTAKE2(0, emissionsPerSecond[0]);

//         STAKE.setDistributionEnd(block.timestamp);

//         SUPER_SILO.deposit(silo, user1, address(incentivesAsset), 1_000_000_000e18, false);
//         SUPER_SILO.deposit(silo, user2, address(incentivesAsset), 100_000e18, false);

//         _jumpSec(10);

//         _claim();
//         emit log_named_decimal_uint("balance after claim from STAKE -->", REWARD_TOKEN.balanceOf(address(user1)), 18);

//         STAKE.rescueRewards();

//         STAKE2.configureAssets(assets, emissionsPerSecond);
//         STAKE2.setDistributionEnd(block.timestamp + 10);
//         siloRepository.setNotificationReceiver(address(silo), STAKE2);

//         _jumpSec(1);

//         _claim();
//         SUPER_SILO.deposit(silo, user2, address(incentivesAsset), 100_000e18, false);

//         _jumpSec(1);
//         _claim();
//         SUPER_SILO.deposit(silo, user1, address(incentivesAsset), 100_000e18, false);
//         _jumpSec(1);
//         _claim();
//         _jumpSec(1);

//         _claimSTAKE2();
//         emit log_named_decimal_uint("balance after claim from STAKE2", REWARD_TOKEN.balanceOf(address(user1)), 18);

//         _jumpSec(1);
//         _claimSTAKE2();
//     }

//     // forge test --gas-price 1 -vv --match-test test_flow
//     function test_flow() public {
//         _info("no rewards setup yes, but users already have some deposits and VIRTUAL rewards will be calculated for them based on shares");
//         _info("user 1 deposit 100 tokens before setup");
//         SUPER_SILO.deposit(silo, user1, address(incentivesAsset), 100e18, false);

//         _info("time before setup rewards does not matter, it will not affect VIRTUAL rewards amount");
//         _jumpSec(30);

//         _info("we have to setup notification receiver for each silo, this will (unfortunately) enable notification for all sTokens");
//         siloRepository.setNotificationReceiver(address(silo), STAKE);

//         _info("minting 40 SILO as rewards.");
//         cheats.prank(REWARD_TOKEN.owner());
//         REWARD_TOKEN.mint(address(STAKE), 40e18);

//         _info("SETUP REWARD DISTRIBUTION");
//         _info("emissionsPerSecond=1e18, this is per sec per totalSupply, reward is constant, it will split among shares");
//         _info("distribution `clock` starts when we call `configureAssets`, starting now.");
//         STAKE.configureAssets(assets, emissionsPerSecond);
//         clockStart = block.timestamp;

//         _printUsersRewards(1, emissionsPerSecond[0]);
//         _info("reward is 0 because there is empty `distributionEnd` time, we have to setup this as well");

//         STAKE.setDistributionEnd(clockStart + 10);

//         _printUsersRewards(0, emissionsPerSecond[0]);

//         _info("user 2 deposit 100 tokens,");
//         SUPER_SILO.deposit(silo, user2, address(incentivesAsset), 100e18, false);

//         _printUsersRewards(0, emissionsPerSecond[0]);

//         _printUsersRewards(9, emissionsPerSecond[0]);

//         _info("'restart' for next 10sec");
//         STAKE.setDistributionEnd(block.timestamp + 10);
//         _printUsersRewards(10, emissionsPerSecond[0]);

//         _info("when distribution Ends, no more rewards will be distributed:");
//         _printUsersRewards(10, 0);

//         _info("changing rewards emission to 2/s and restart for next 10sec");
//         emissionsPerSecond[0] = 2e18;

//         STAKE.configureAssets(assets, emissionsPerSecond);
//         STAKE.setDistributionEnd(block.timestamp + 10);

//         _info("for gap between DistributionEnd and restartm rewards should be not distributed");
//         _printUsersRewards(0, emissionsPerSecond[0]);

//         _info("user 2 deposit 100 tokens as collateral only, it should not affect rewards, because they are not set for collateral ONLY");
//         SUPER_SILO.deposit(silo, user2, address(incentivesAsset), 100e18, true);
//         _printUsersRewards(5, emissionsPerSecond[0]);

//         _info("when user2 withdraw, automatic checkpoint is applied and rewards are calculated");
//         cheats.prank(user2);
//         silo.withdraw(address(incentivesAsset), 50e18, false);
//         _printUsersRewards(0, emissionsPerSecond[0]);

//         _info("user2 claimRewards");
//         cheats.prank(user2);
//         STAKE.claimRewards(assets, type(uint256).max, user2);
//         _printUsersRewards(0, emissionsPerSecond[0]);

//         _info("user2 withdraws all whats left");
//         cheats.prank(user2);
//         silo.withdraw(address(incentivesAsset), 50e18, false);
//         _printUsersRewards(0, emissionsPerSecond[0]);

//         _info("Self-transfer should not increase rewards");
//         uint256 rewardsBefore = STAKE.getRewardsBalance(assets, user1);
//         cheats.prank(user1);
//         collateralToken.transfer(user1, 10e18);
//         uint256 rewardsAfter = STAKE.getRewardsBalance(assets, user1);

//         assertEq(rewardsAfter, rewardsBefore, "Self-transfer increased rewards");

//         _info("user1 transfers 50 tokens to user 2 (testing if we need to handleAction for address _to)");
//         cheats.prank(user1);
//         collateralToken.transfer(user2, 50e18);
//         _printUsersRewards(0, emissionsPerSecond[0]);
//         _printUsersRewards(5, emissionsPerSecond[0]);

//         _info("claimRewards");
//         _claim();

//         cheats.prank(user1);
//         silo.withdraw(address(incentivesAsset), 50e18, false);

//         _printUsersRewards(0, 0);

//         emit log_named_decimal_uint("user1 reward balance", REWARD_TOKEN.balanceOf(user1), 18);
//         emit log_named_decimal_uint("user2 reward balance", REWARD_TOKEN.balanceOf(user2), 18);
//         emit log_named_decimal_uint("STAKE contract reward balance", REWARD_TOKEN.balanceOf(address(STAKE)), 18);

//         assertEq(REWARD_TOKEN.balanceOf(user1), 205e17, "invalid user1 balance");
//         assertEq(REWARD_TOKEN.balanceOf(user2), 195e17, "invalid user2 balance");
//         assertEq(REWARD_TOKEN.balanceOf(address(STAKE)), 0, "invalid STAKE balance");

//         _info("rescueRewards");
//         STAKE.rescueRewards();
//     }

//     function _jumpSec(uint256 _time) internal {
//         emit log_named_uint("time +sec", _time);
//         cheats.warp(block.timestamp + _time); // total 10sec
//     }

//     function _info(string memory _i) internal {
//         emit log(string(abi.encodePacked("\n# ", _i, "\n"))); // total 10sec
//     }

//     function _printUsersRewards(uint256 _jump, uint256 _emission) internal {
//         if (_jump != 0) _jumpSec(_jump);
//         if (_emission != 0) trackRewardsSum += _jump * _emission;

//         emit log_named_uint("-------------------- time pass", clockStart == 0 ? 0 : block.timestamp - clockStart);

//         uint256 sum = STAKE.getRewardsBalance(assets, user1) + STAKE.getRewardsBalance(assets, user2);

//         emit log_named_decimal_uint("rewards for user1", STAKE.getRewardsBalance(assets, user1), 18);
//         emit log_named_decimal_uint("getUserUnclaimedRewards", STAKE.getUserUnclaimedRewards(user1), 18);
//         emit log_named_decimal_uint("reward user2", STAKE.getRewardsBalance(assets, user2), 18);
//         emit log_named_decimal_uint("getUserUnclaimedRewards", STAKE.getUserUnclaimedRewards(user2), 18);

//         emit log_named_decimal_uint("SUM", sum, 18);
//     }

//     function _printUsersRewardsSTAKE2(uint256 _jump, uint256 _emission) internal {
//         if (_jump != 0) _jumpSec(_jump);
//         if (_emission != 0) trackRewardsSum += _jump * _emission;

//         emit log_named_uint("-------------------- time pass", clockStart == 0 ? 0 : block.timestamp - clockStart);

//         uint256 sum = STAKE2.getRewardsBalance(assets, user1) + STAKE2.getRewardsBalance(assets, user2);

//         emit log_named_decimal_uint("STAKE2 rewards for user1", STAKE2.getRewardsBalance(assets, user1), 18);
//         emit log_named_decimal_uint("STAKE2 getUserUnclaimedRewards", STAKE2.getUserUnclaimedRewards(user1), 18);
//         emit log_named_decimal_uint("STAKE2 reward user2", STAKE2.getRewardsBalance(assets, user2), 18);
//         emit log_named_decimal_uint("STAKE2 getUserUnclaimedRewards", STAKE2.getUserUnclaimedRewards(user2), 18);

//         emit log_named_decimal_uint("SUM", sum, 18);
//     }

//     function _claim() internal {
//         cheats.prank(user1);
//         STAKE.claimRewards(assets, type(uint256).max, user1);
//         cheats.prank(user2);
//         STAKE.claimRewards(assets, type(uint256).max, user2);
//     }

//     function _claimSTAKE2() internal {
//         cheats.prank(user1);
//         STAKE2.claimRewards(assets, type(uint256).max, user1);
//         cheats.prank(user2);
//         STAKE2.claimRewards(assets, type(uint256).max, user2);
//     }
// }
