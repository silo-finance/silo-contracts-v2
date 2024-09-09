// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Test} from "forge-std/Test.sol";

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {IVeSilo} from "ve-silo/contracts/voting-escrow/interfaces/IVeSilo.sol";
import {IVeBoost} from "ve-silo/contracts/voting-escrow/interfaces/IVeBoost.sol";
import {ISmartWalletChecker} from "ve-silo/contracts/voting-escrow/interfaces/ISmartWalletChecker.sol";
import {VotingEscrowDeploy} from "ve-silo/deploy/VotingEscrowDeploy.s.sol";
import {VeBoostDeploy} from "ve-silo/deploy/VeBoostDeploy.s.sol";
import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {VotingEscrowChildChainDeploy} from "ve-silo/deploy/VotingEscrowChildChainDeploy.s.sol";
import {ERC20Mint as ERC20} from "ve-silo/test/_mocks/ERC20Mint.sol";

// FOUNDRY_PROFILE=ve-silo-test forge test --mc VotingEscrowTest --ffi -vvv
contract VotingEscrowTest is IntegrationTest {
    IVeSilo internal _votingEscrow;
    IVeBoost internal _veBoost;
    VotingEscrowDeploy internal _veDeploymentScript;
    VeBoostDeploy internal _veBoostDeploymentScript;

    address internal _timelock = makeAddr("silo timelock");
    address internal _smartValletChecker = makeAddr("Smart wallet checker");
    address internal _user = makeAddr("test user1");

    uint256 internal constant _FORKING_BLOCK_NUMBER = 17336000;

    function setUp() public {
        vm.createSelectFork(
            getChainRpcUrl(MAINNET_ALIAS),
            _FORKING_BLOCK_NUMBER
        );

        (_votingEscrow, _veBoost) = deployVotingEscrowForTests();
    }

    function deployVotingEscrowForTests() public returns (IVeSilo veSilo, IVeBoost veBoost) {
        _veDeploymentScript = new VotingEscrowDeploy();
        _veDeploymentScript.disableDeploymentsSync();

        _mockPermissions();
        _dummySiloToken();

        veSilo = _veDeploymentScript.run();

        setAddress(getChainId(), VeSiloContracts.VOTING_ESCROW_CHILD_CHAIN, address(veSilo));

        _veBoostDeploymentScript = new VeBoostDeploy();

        veBoost = _veBoostDeploymentScript.run();

        vm.prank(_timelock);
        veSilo.commit_smart_wallet_checker(_smartValletChecker);

        vm.prank(_timelock);
        veSilo.apply_smart_wallet_checker();

        _votingEscrow = veSilo;
        _veBoost = veBoost;
    }

    function getVeSiloTokens(address _userAddr, uint256 _amount, uint256 _unlockTime) public {
        whiteListUser(_userAddr);

        IERC20 siloToken = IERC20(getAddress(SILO_TOKEN));

        deal(address(siloToken), _userAddr, _amount);

        vm.prank(_userAddr);
        siloToken.approve(address(_votingEscrow), _amount);

        vm.prank(_userAddr);
        _votingEscrow.create_lock(_amount, _unlockTime);
    }

    function testEnsureDeployedWithCorrectData() public {
        address siloToken = getAddress(SILO_TOKEN);

        assertEq(_votingEscrow.token(), siloToken, "Invalid voting escrow token");
        assertEq(_votingEscrow.name(), _veDeploymentScript.votingEscrowName(), "Wrong name");
        assertEq(_votingEscrow.symbol(), _veDeploymentScript.votingEscrowSymbol(), "Wrong symbol");

        assertEq(
            _votingEscrow.decimals(),
            IERC20(siloToken).decimals(),
            "Decimals should be the same with as a token decimals"
        );

        assertEq(_veBoost.BOOST_V1(), address(0), "veBoostV1 makes no sense");
        assertEq(_veBoost.VE(), address(_votingEscrow), "An invalid VotingEscrow address");
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testLockPeriodsForCreateLock --ffi -vvv
    function testLockPeriodsForCreateLock() public {
        uint256 tokensAmount = 11 ether;

        uint256 timestamp = 1;
        uint256 maxTime = 365 * 86400 * 3;

        vm.warp(timestamp);

        vm.prank(_user);
        vm.expectRevert("Voting lock can be 3 years max");
        _votingEscrow.create_lock(tokensAmount, maxTime + 2 weeks);

        vm.prank(_user);
        vm.expectRevert("Voting lock can be 2 weeks min");
        _votingEscrow.create_lock(tokensAmount, timestamp + 1 weeks);
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testLockPeriodsIncreaseUnlockTime --ffi -vvv
    function testLockPeriodsIncreaseUnlockTime() public {
        uint256 tokensAmount = 11 ether;

        uint256 timestamp = 1;
        uint256 year = 365 * 24 * 3600;
        uint256 maxTime = 365 * 86400 * 3;

        vm.warp(timestamp);

        getVeSiloTokens(_user, tokensAmount, year);
        uint256 votingPower = _votingEscrow.balanceOf(_user);
        assertEq(votingPower, 3656620888271703527);

        vm.warp(year - 1 weeks);

        votingPower = _votingEscrow.balanceOf(_user);
        assertEq(votingPower, 60273972602323200);

        vm.prank(_user);
        vm.expectRevert("Voting lock can be 3 years max");
        _votingEscrow.increase_unlock_time(block.timestamp + maxTime + 2 weeks);

        vm.prank(_user);
        vm.expectRevert("Voting lock can be 2 weeks min");
        _votingEscrow.increase_unlock_time(block.timestamp + 2 weeks);
    }

    function testGetVeSiloTokens() public {
        uint256 tokensAmount = 11 ether;

        uint256 timestamp = 1;
        uint256 year = 365 * 24 * 3600;

        vm.warp(timestamp);

        getVeSiloTokens(_user, tokensAmount, year);

        uint256 votingPower = _votingEscrow.balanceOf(_user);

        assertEq(votingPower, 3656620888271703527);
    }

    function whiteListUser(address _userToWhitelist) public {
        vm.mockCall(
            _smartValletChecker,
            abi.encodeCall(ISmartWalletChecker.check, _userToWhitelist),
            abi.encode(true)
        );
    }

    function _mockPermissions() internal {
        setAddress(VeSiloContracts.TIMELOCK_CONTROLLER, _timelock);
        whiteListUser(_user);
    }

    function _dummySiloToken() internal {
        if (isChain(ANVIL_ALIAS) || isChain(SEPOLIA_ALIAS)) {
            ERC20 siloToken = new ERC20("Silo test token", "SILO");

            setAddress(getChainId(), SILO_TOKEN, address(siloToken));
        }
    }
}
