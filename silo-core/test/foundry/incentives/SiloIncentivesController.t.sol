// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {ERC20Mock} from "openzeppelin5/mocks/token/ERC20Mock.sol";

import {SiloIncentivesController} from "silo-core/contracts/incentives/SiloIncentivesController.sol";
import {DistributionTypes} from "silo-core/contracts/incentives/lib/DistributionTypes.sol";
import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";
import {IDistributionManager} from "silo-core/contracts/incentives/interfaces/IDistributionManager.sol";

// FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc SiloIncentivesControllerTest
contract SiloIncentivesControllerTest is Test {
    SiloIncentivesController internal _controller;

    address internal _owner = makeAddr("Owner");
    address internal _notifier;
    address internal _rewardToken;
    
    uint256 internal constant _PRECISION = 10 ** 18;
    uint256 internal constant _TOTAL_SUPPLY = 1000e18;
    string internal constant _PROGRAM_NAME = "Test";
    bytes32 internal constant _PROGRAM_ID = keccak256(abi.encodePacked(_PROGRAM_NAME));

    event IncentivesProgramCreated(bytes32 indexed incentivesProgramId);
    event IncentivesProgramUpdated(bytes32 indexed programId);

    function setUp() public {
        _rewardToken = address(new ERC20Mock());
        _notifier = address(new ERC20Mock());

        _controller = new SiloIncentivesController(_owner, _notifier);

        ERC20Mock(_notifier).mint(address(this), _TOTAL_SUPPLY);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_createIncentivesProgram_OwnableUnauthorizedAccount
    function test_createIncentivesProgram_OwnableUnauthorizedAccount() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));

        _controller.createIncentivesProgram(DistributionTypes.IncentivesProgramCreationInput({
            name: _PROGRAM_NAME,
            rewardToken: address(0),
            distributionEnd: 0,
            emissionPerSecond: 0
        }));
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_createIncentivesProgram_InvalidIncentivesProgramName
    function test_createIncentivesProgram_InvalidIncentivesProgramName() public {
        vm.expectRevert(abi.encodeWithSelector(ISiloIncentivesController.InvalidIncentivesProgramName.selector));

        vm.prank(_owner);
        _controller.createIncentivesProgram(DistributionTypes.IncentivesProgramCreationInput({
            name: "",
            rewardToken: address(0),
            distributionEnd: 0,
            emissionPerSecond: 0
        }));
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_createIncentivesProgram_InvalidRewardToken
    function test_createIncentivesProgram_InvalidRewardToken() public {
        vm.expectRevert(abi.encodeWithSelector(ISiloIncentivesController.InvalidRewardToken.selector));

        vm.prank(_owner);
        _controller.createIncentivesProgram(DistributionTypes.IncentivesProgramCreationInput({
            name: _PROGRAM_NAME,
            rewardToken: address(0),
            distributionEnd: 0,
            emissionPerSecond: 0
        }));
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_createIncentivesProgram_Success
    function test_createIncentivesProgram_Success() public {
        uint104 emissionPerSecond = 1000e18;
        uint256 distributionEnd = block.timestamp + 1000;

        (,, uint256 lastUpdateTimestampBefore, ) = _controller.getIncentivesProgramData(_PROGRAM_NAME);

        vm.expectEmit(true, true, true, true);
        emit IncentivesProgramCreated(_PROGRAM_ID);

        vm.prank(_owner);
        _controller.createIncentivesProgram(DistributionTypes.IncentivesProgramCreationInput({
            name: _PROGRAM_NAME,
            rewardToken: _rewardToken,
            distributionEnd: uint40(distributionEnd),
            emissionPerSecond: emissionPerSecond
        }));

        (
            uint256 indexCurrent,
            uint256 emissionPerSecondCurrent,
            uint256 lastUpdateTimestampCurrent,
            uint256 distributionEndCurrent
        ) = _controller.getIncentivesProgramData(_PROGRAM_NAME);

        uint256 expectedIndex =
            emissionPerSecond * (block.timestamp - lastUpdateTimestampBefore) * _PRECISION / _TOTAL_SUPPLY;

        assertEq(emissionPerSecondCurrent, emissionPerSecond);
        assertEq(lastUpdateTimestampCurrent, block.timestamp);
        assertEq(distributionEndCurrent, distributionEnd);
        assertEq(indexCurrent, expectedIndex);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_updateIncentivesProgram_IncentivesProgramAlreadyExists
    function test_updateIncentivesProgram_IncentivesProgramAlreadyExists() public {
        vm.prank(_owner);
        _controller.createIncentivesProgram(DistributionTypes.IncentivesProgramCreationInput({
            name: _PROGRAM_NAME,
            rewardToken: _rewardToken,
            distributionEnd: uint40(block.timestamp + 1000),
            emissionPerSecond: 1000e18
        }));

        vm.expectRevert(abi.encodeWithSelector(ISiloIncentivesController.IncentivesProgramAlreadyExists.selector));

        vm.prank(_owner);
        _controller.createIncentivesProgram(DistributionTypes.IncentivesProgramCreationInput({
            name: _PROGRAM_NAME,
            rewardToken: _rewardToken,
            distributionEnd: uint40(block.timestamp + 1000),
            emissionPerSecond: 1000e18
        }));
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_updateIncentivesProgram_InvalidDistributionEnd
    function test_updateIncentivesProgram_InvalidDistributionEnd() public {
        vm.prank(_owner);
        _controller.createIncentivesProgram(DistributionTypes.IncentivesProgramCreationInput({
            name: _PROGRAM_NAME,
            rewardToken: _rewardToken,
            distributionEnd: uint40(block.timestamp + 1000),
            emissionPerSecond: 1000e18
        }));

        vm.expectRevert(abi.encodeWithSelector(ISiloIncentivesController.InvalidDistributionEnd.selector));

        vm.prank(_owner);
        _controller.updateIncentivesProgram(_PROGRAM_NAME, uint40(block.timestamp - 1), 1000e18);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_updateIncentivesProgram_IncentivesProgramNotFound
    function test_updateIncentivesProgram_IncentivesProgramNotFound() public {
        vm.expectRevert(abi.encodeWithSelector(ISiloIncentivesController.IncentivesProgramNotFound.selector));

        vm.prank(_owner);
        _controller.updateIncentivesProgram(_PROGRAM_NAME, uint40(block.timestamp + 1000), 1000e18);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_updateIncentivesProgram_Success
    function test_updateIncentivesProgram_Success() public {
        uint40 distributionEnd = uint40(block.timestamp + 1000);
        uint104 emissionPerSecond = 1000e18;

        vm.prank(_owner);
        _controller.createIncentivesProgram(DistributionTypes.IncentivesProgramCreationInput({
            name: _PROGRAM_NAME,
            rewardToken: _rewardToken,
            distributionEnd: distributionEnd,
            emissionPerSecond: emissionPerSecond
        }));

        (
            uint256 indexBefore,
            uint256 emissionPerSecondBefore,
            uint256 lastUpdateTimestampBefore,
            uint256 distributionEndBefore
        ) = _controller.getIncentivesProgramData(_PROGRAM_NAME);

        assertEq(emissionPerSecondBefore, emissionPerSecond);
        assertEq(distributionEndBefore, distributionEnd);

        vm.warp(block.timestamp + 1000);

        distributionEnd = uint40(block.timestamp + 2000);
        emissionPerSecond = 2000e18;

        vm.expectEmit(true, true, true, true);
        emit IncentivesProgramUpdated(_PROGRAM_ID);

        vm.prank(_owner);
        _controller.updateIncentivesProgram(_PROGRAM_NAME, distributionEnd, emissionPerSecond);

        (
            uint256 indexCurrent,
            uint256 emissionPerSecondCurrent,
            uint256 lastUpdateTimestampCurrent,
            uint256 distributionEndCurrent
        ) = _controller.getIncentivesProgramData(_PROGRAM_NAME);

        uint256 expectedIndex = indexBefore +
            emissionPerSecond * (block.timestamp - lastUpdateTimestampBefore) * _PRECISION / _TOTAL_SUPPLY;

        assertEq(indexCurrent, expectedIndex);
        assertEq(emissionPerSecondCurrent, emissionPerSecond);
        assertEq(distributionEndCurrent, distributionEnd);
        assertEq(lastUpdateTimestampCurrent, block.timestamp);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_afterTokenTransfer_OnlyNotifier
    function test_afterTokenTransfer_OnlyNotifier() public {
        vm.expectRevert(abi.encodeWithSelector(IDistributionManager.OnlyNotifier.selector));

        _controller.afterTokenTransfer(address(0), 0, address(0), 0, 0, 0);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_afterTokenTransfer_ShouldNotRevert
    function test_afterTokenTransfer_ShouldNotRevert() public {
        vm.prank(_notifier);
        _controller.afterTokenTransfer(address(0), 0, address(0), 0, 0, 0);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_afterTokenTransfer_Success
    function test_afterTokenTransfer_Success() public {
        uint40 distributionEnd = uint40(block.timestamp + 30 days);
        uint104 emissionPerSecond = 100e18;

        vm.prank(_owner);
        _controller.createIncentivesProgram(DistributionTypes.IncentivesProgramCreationInput({
            name: _PROGRAM_NAME,
            rewardToken: _rewardToken,
            distributionEnd: distributionEnd,
            emissionPerSecond: emissionPerSecond
        }));

        address recipient = makeAddr("Recipient");
        uint256 recipientBalance = 100e18;
        uint256 newTotalSupply = _TOTAL_SUPPLY + recipientBalance;
        uint256 amount = recipientBalance;

        ERC20Mock(_notifier).mint(recipient, recipientBalance);

        uint256 userDataBefore = _controller.getUserData(recipient, _PROGRAM_NAME);
        assertEq(userDataBefore, 0);

        vm.warp(block.timestamp + 1 days);

        vm.prank(_notifier);
        _controller.afterTokenTransfer(address(0), 0, recipient, recipientBalance, newTotalSupply, amount);

        (uint256 indexAfter,,,) = _controller.getIncentivesProgramData(_PROGRAM_NAME);

        uint256 userDataAfter = _controller.getUserData(recipient, _PROGRAM_NAME);

        (,, uint256 lastUpdateTimestamp, ) = _controller.getIncentivesProgramData(_PROGRAM_NAME);

        uint256 expectedIndex = indexAfter +
            emissionPerSecond * (block.timestamp - lastUpdateTimestamp) * _PRECISION / newTotalSupply;

        assertEq(expectedIndex, indexAfter);
        assertEq(userDataAfter, expectedIndex);

        vm.warp(block.timestamp + 10 days);

        uint256 rewards = _controller.getRewardsBalance(recipient, _PROGRAM_NAME);

        expectedIndex = expectedIndex +
            emissionPerSecond * (block.timestamp - lastUpdateTimestamp) * _PRECISION / newTotalSupply;

        uint256 expectedRewards = recipientBalance * (expectedIndex - userDataAfter) / _PRECISION;
        expectedRewards += _controller.getUserUnclaimedRewards(recipient, _PROGRAM_NAME);

        assertEq(rewards, expectedRewards);
        assertNotEq(rewards, 0);
    }
}
