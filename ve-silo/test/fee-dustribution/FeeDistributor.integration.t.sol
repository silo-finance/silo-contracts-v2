// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {IVeSilo} from "ve-silo/contracts/voting-escrow/interfaces/IVeSilo.sol";
import {IVeBoost} from "ve-silo/contracts/voting-escrow/interfaces/IVeBoost.sol";
import {FeeDistributorDeploy} from "ve-silo/deploy/FeeDistributorDeploy.s.sol";
import {VotingEscrowTest} from "ve-silo/test/voting-escrow/VotingEscrow.integration.t.sol";
import {IFeeDistributor} from "ve-silo/contracts/fees-distribution/interfaces/IFeeDistributor.sol";
import {ERC20Mint} from "ve-silo/test/_mocks/ERC20Mint.sol";

// FOUNDRY_PROFILE=ve-silo-test forge test --mc FeeDistributorTest --ffi -vvv
contract FeeDistributorTest is IntegrationTest {
    uint256 constant internal _VE_SILO_TOKENS_BAL = 100e18;
    uint256 constant internal _TOKENS_TO_DISTRIBUTE = 1000_000e18;

    IVeSilo internal _votingEscrow;
    IVeBoost internal _veBoost;
    IFeeDistributor internal _feesDistributor;

    FeeDistributorDeploy internal _feeDistributorDeploy;
    VotingEscrowTest internal _votingEscrowTest;

    ERC20Mint internal _feesToken;
    IERC20 internal _erc20feesToken;

    address internal _user1 = makeAddr("User1");
    address internal _user2 = makeAddr("User2");
    address internal _tokenHolder = makeAddr("Token holder");

    function setUp() public {
        _votingEscrowTest = new VotingEscrowTest();

        (_votingEscrow, _veBoost) = _votingEscrowTest.deployVotingEscrowForTests();

        _feeDistributorDeploy = new FeeDistributorDeploy();
        _feeDistributorDeploy.disableDeploymentsSync();

        _feesDistributor = _feeDistributorDeploy.run();

        _feesToken = new ERC20Mint("Fees token", "FT");
        _erc20feesToken = IERC20(address(_feesToken));
    }

    function testShouldDistributeTokens() public {
        uint256 lockTime = _feeDistributorDeploy.startTime() - 1 weeks;
        vm.warp(lockTime);

        uint256 unlockTime = lockTime + 365 days;

        _votingEscrowTest.getVeSiloTokens(_user1,  _VE_SILO_TOKENS_BAL, unlockTime);
        _votingEscrowTest.getVeSiloTokens(_user2,  _VE_SILO_TOKENS_BAL, unlockTime);

        vm.warp(lockTime + 1 weeks + 1 seconds);

        _feesToken.mint(_tokenHolder, _TOKENS_TO_DISTRIBUTE);

        vm.prank(_tokenHolder);
        _feesToken.approve(address(_feesDistributor), _TOKENS_TO_DISTRIBUTE);

        vm.prank(_tokenHolder);
        _feesDistributor.depositToken(_erc20feesToken, _TOKENS_TO_DISTRIBUTE);

        _feesDistributor.checkpoint();
        _feesDistributor.checkpointUser(_user1);
        _feesDistributor.checkpointUser(_user2);

        vm.warp(lockTime + 2 weeks);

        _feesDistributor.checkpointToken(_erc20feesToken);

        vm.warp(_feeDistributorDeploy.startTime() + 3 weeks);

        uint256 user1TimeCursor = _feesDistributor.getUserTimeCursor(_user1);
        uint256 user2TimeCursor = _feesDistributor.getUserTimeCursor(_user2);

        assertTrue(user1TimeCursor != 0 && user2TimeCursor != 0, "Time cursor should not be 0");

        uint256 user1Balance = _feesToken.balanceOf(_user1);
        uint256 user2Balance = _feesToken.balanceOf(_user2);

        assertTrue(user1Balance == 0 && user2Balance == 0, "Fees token balance should be 0");

        vm.warp(_feeDistributorDeploy.startTime() + 10 weeks);

        uint256 claimedUser1 = _feesDistributor.claimToken(_user1, _erc20feesToken);
        uint256 claimedUser2 = _feesDistributor.claimToken(_user2, _erc20feesToken);

        user1Balance = _feesToken.balanceOf(_user1);
        user2Balance = _feesToken.balanceOf(_user2);

        assertEq(claimedUser1, user1Balance, "Failed to claim tokens");
        assertEq(claimedUser2, user2Balance, "Failed to claim tokens");
        assertTrue(user1Balance != 0 && user2Balance != 0, "Failed to claim tokens, balance is 0");
    }
}
