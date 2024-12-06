// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {ERC20Mock} from "openzeppelin5/mocks/token/ERC20Mock.sol";

import {SiloIncentivesController} from "silo-core/contracts/incentives/SiloIncentivesController.sol";
import {DistributionTypes} from "silo-core/contracts/incentives/lib/DistributionTypes.sol";
import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";
import {IDistributionManager} from "silo-core/contracts/incentives/interfaces/IDistributionManager.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";


import {SiloConfigOverride} from "../_common/fixtures/SiloFixture.sol";
import {SiloFixtureWithVeSilo as SiloFixture} from "../_common/fixtures/SiloFixtureWithVeSilo.sol";

import {MintableToken} from "../_common/MintableToken.sol";
import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

contract HookContract {
    SiloIncentivesController controller;
    MintableToken notifierToken;

    function setup(
        SiloIncentivesController _controller,
        MintableToken _notifierToken
    ) public {
        controller = _controller;
        notifierToken = _notifierToken;
    }

    function totalSupply() external view returns (uint256) {
        return notifierToken.totalSupply();
    }

    function balanceOf(address _user) external view returns (uint256) {
        return notifierToken.balanceOf(_user);
    }

    function hookReceiverConfig(address) external view returns (uint24 hooksBefore, uint24 hooksAfter) {
        hooksAfter = uint24(Hook.SHARE_TOKEN_TRANSFER | Hook.COLLATERAL_TOKEN);
    }

    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput) external {
        Hook.AfterTokenTransfer memory input = Hook.afterTokenTransferDecode(_inputAndOutput);

        controller.afterTokenTransfer(
            input.sender, input.senderBalance, input.recipient, input.recipientBalance, input.totalSupply, input.amount
        );
    }
}

// FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc SiloIncentivesControllerTest
contract SiloIncentivesControllerIntegrationTest is SiloLittleHelper, Test {
    SiloIncentivesController internal _controller;

    address internal _notifier;
    MintableToken internal _rewardToken;
    HookContract hook;

    address internal user1 = makeAddr("User1");
    address internal user2 = makeAddr("User2");
    address internal user3 = makeAddr("User3");

    uint256 internal constant _PRECISION = 10 ** 18;
    string internal constant _PROGRAM_NAME = "Test";
    bytes32 internal constant _PROGRAM_ID = keccak256(abi.encodePacked(_PROGRAM_NAME));

    event IncentivesProgramCreated(bytes32 indexed incentivesProgramId);
    event IncentivesProgramUpdated(bytes32 indexed programId);
    event ClaimerSet(address indexed user, address indexed claimer);

    function _setUp() internal {
        hook = new HookContract();

        token0 = new MintableToken(18);
        token1 = new MintableToken(18);
        _rewardToken = new MintableToken(18);

        token0.setOnDemand(true);
        token1.setOnDemand(true);

        SiloFixture siloFixture = new SiloFixture();
        SiloConfigOverride memory overrides;
        overrides.token0 = address(token0);
        overrides.token1 = address(token1);
        overrides.hookReceiver = address(hook);

        (, silo0, silo1,,,) = siloFixture.deploy_local(overrides);

        __init(token0, token1, silo0, silo1);

        _controller = new SiloIncentivesController(address(this), address(hook));
        hook.setup(_controller, token0);

        silo0.updateHooks();
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --ffi --mt test_scenario_parallel_programs -vvv
    */
    function test_scenario_parallel_programs() public {
        _setUp();

        _controller.createIncentivesProgram(DistributionTypes.IncentivesProgramCreationInput({
            name: _PROGRAM_NAME,
            rewardToken: address(_rewardToken),
            distributionEnd: uint40(block.timestamp + 100),
            emissionPerSecond: 100
        }));

        _controller.setDistributionEnd(_PROGRAM_NAME, uint40(block.timestamp + 100)); // again??

        assertEq(_controller.getRewardsBalance(user1, _PROGRAM_NAME), 0, "no rewards without deposit");

        _deposit(100e18, user1);

        vm.warp(block.timestamp + 1);

        assertEq(_controller.getRewardsBalance(user1, _PROGRAM_NAME), 0, "still no rewards?");

        vm.startPrank(address(hook));
        _controller.immediateDistribution(_PROGRAM_ID, 55, token0.totalSupply());
        vm.stopPrank();

        assertEq(_rewardToken.balanceOf(user1), 0, "rewards before");
        _controller.claimRewards(user1);
        assertEq(_rewardToken.balanceOf(user1), 10, "rewards after");

        assertEq(_controller.getRewardsBalance(user1, _PROGRAM_NAME), 100, "getRewardsBalance in main program after 1 sec");


//        vm.prank(notifier);
//        _controller.immediateDistribution(_PROGRAM_ID, uint104(toDistribute), totalSupply);
        // user3 claim rewards
//        vm.prank(user3);
//        _controller.claimRewards(user3);
//
//        assertEq(ERC20Mock(_rewardToken).balanceOf(user1), expectedRewardsUser1, "invalid user1 balance");
//        assertEq(ERC20Mock(_rewardToken).balanceOf(user2), expectedRewardsUser2, "invalid user2 balance");
//        assertEq(ERC20Mock(_rewardToken).balanceOf(user3), expectedRewardsUser3, "invalid user3 balance");
    }
}
