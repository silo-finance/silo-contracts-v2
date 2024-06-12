// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {SiloGovernorDeploy} from "ve-silo/deploy/SiloGovernorDeploy.s.sol";

import {ISiloGovernor} from "ve-silo/contracts/governance/interfaces/ISiloGovernor.sol";
import {IVeSilo} from "ve-silo/contracts/voting-escrow/interfaces/IVeSilo.sol";
import {ISiloTimelockController} from "ve-silo/contracts/governance/interfaces/ISiloTimelockController.sol";
import {ISmartWalletChecker} from "ve-silo/contracts/voting-escrow/interfaces/ISmartWalletChecker.sol";

// FOUNDRY_PROFILE=ve-silo-test forge test --mc SiloGovernorTest --ffi -vvv
contract SiloGovernorTest is IntegrationTest {
    uint256 internal constant _FORKING_BLOCK_NUMBER = 17436270;

    SiloGovernorDeploy internal _deploymentScript;

    ISiloGovernor internal _siloGovernor;
    ISiloTimelockController internal _timelock;
    IVeSilo internal _votingEscrow;

    address internal _voter = makeAddr("test _voter1");
    address internal _fakeChecker = makeAddr("Fake smart wallet checker");
    address internal _newChecker = makeAddr("New smart wallet checker");

    function setUp() public {
        vm.createSelectFork(
            getChainRpcUrl(MAINNET_ALIAS),
            _FORKING_BLOCK_NUMBER
        );

        _deploymentScript = new SiloGovernorDeploy();

        _deploymentScript.disableDeploymentsSync();

        (_siloGovernor, _timelock, _votingEscrow, ) = _deploymentScript.run();
    }

    function testEnsureDeployedWithCorrectConfigurations() public {
        // veSilo token
        IVeSilo daoVotingToken = _siloGovernor.veSiloToken();
        assertEq(address(daoVotingToken), address(_votingEscrow), "An invalid veSiloToken after deployment");

        address siloGovernorAddr = address(_siloGovernor);

        // timelockController roles
        bytes32 proposerRole = _timelock.PROPOSER_ROLE();
        bytes32 executorRole = _timelock.EXECUTOR_ROLE();
        bytes32 cancellerRole = _timelock.CANCELLER_ROLE();
        bytes32 adminRole = _timelock.DEFAULT_ADMIN_ROLE();

        // DAO should have all roles
        assertTrue(_timelock.hasRole(proposerRole, siloGovernorAddr), "DAO should have a PROPOSER_ROLE role");
        assertTrue(_timelock.hasRole(executorRole, siloGovernorAddr), "DAO should have an EXECUTOR_ROLE role");
        assertTrue(_timelock.hasRole(cancellerRole, siloGovernorAddr), "DAO should have a CANCELLER_ROLE role");
        assertTrue(_timelock.hasRole(adminRole, siloGovernorAddr), "DAO should have a DEFAULT_ADMIN_ROLE role");

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address deployer = vm.addr(deployerPrivateKey);

        // Deploye should not have roles
        assertTrue(!_timelock.hasRole(proposerRole, deployer), "Deployer should not have a PROPOSER_ROLE role");
        assertTrue(!_timelock.hasRole(executorRole, deployer), "Deployer should not have an EXECUTOR_ROLE role");
        assertTrue(!_timelock.hasRole(cancellerRole, deployer), "Deployer should not a CANCELLER_ROLE role");
        assertTrue(!_timelock.hasRole(adminRole, deployer), "Deployer should not a DEFAULT_ADMIN_ROLE role");

        // veSilo token admin is a TimelockController
        assertEq(
            _votingEscrow.admin(),
            address(_timelock),
            "TimelockController should be an admin of the veSilo token"
        );
    }

    function testProposals() public {
        // We will do test on the protected veSilo token functions
        // where we will configure a smart wallet checker

        // Expect to have an empty state
        assertEq(_votingEscrow.future_smart_wallet_checker(), address(0), "Expect to have an empty state");
        assertEq(_votingEscrow.smart_wallet_checker(), address(0), "Expect to have an empty state");

        // Ensure that a `voter` is not capable of updating a smart wallet checker
        _protectedFunctionsShouldRevert();

        // Create a fake smart wallet checker to be able to execute a test
        _configureFakeSmartWalletChecker();

        // Get a voting power for the `_voter`
        _getVeSiloTokens(_voter, 200_000_000e18, 365 * 24 * 3_600);

        // Execute two actions in a single proposal:
        // - `commit_smart_wallet_checker`
        // - `apply_smart_wallet_checker`
        _executeProposals(_newChecker);

        // Expecting to have a new smart wallet checker
        assertEq(_votingEscrow.smart_wallet_checker(), _newChecker, "An invalid result of the proposal execution");
    }

    function _protectedFunctionsShouldRevert() internal {
        vm.prank(_voter);
        vm.expectRevert();
        _votingEscrow.commit_smart_wallet_checker(address(1));

        vm.prank(_voter);
        vm.expectRevert();
        _votingEscrow.apply_smart_wallet_checker();
    }

    function _getVeSiloTokens(address _userAddr, uint256 _amount, uint256 _unlockTime) internal {
        IERC20 siloToken = IERC20(getAddress(SILO_TOKEN));

        deal(address(siloToken), _userAddr, _amount);

        vm.prank(_userAddr);
        siloToken.approve(address(_votingEscrow), _amount);

        uint256 lockedTo = block.timestamp + _unlockTime;

        vm.prank(_userAddr);
        _votingEscrow.create_lock(_amount, lockedTo);
    }

    function _configureFakeSmartWalletChecker() internal {
        vm.prank(address(_timelock));
        _votingEscrow.commit_smart_wallet_checker(_fakeChecker);

        vm.prank(address(_timelock));
        _votingEscrow.apply_smart_wallet_checker();

        assertEq(
            _votingEscrow.smart_wallet_checker(),
            _fakeChecker,
            "Failed to configure a fake smart wallet checker"
        );

        vm.mockCall(
            _fakeChecker,
            abi.encodeCall(ISmartWalletChecker.check, _voter),
            abi.encode(true)
        );
    }

    // solhint-disable-next-line function-max-lines
    function _executeProposals(address _checker) internal {
        // two calls into veSilo token
        address[] memory targets = new address[](2);
        targets[0] = address(_votingEscrow);
        targets[1] = address(_votingEscrow);

        // Empty values
        uint256[] memory values = new uint256[](2);

        // Functions inputs
        bytes[] memory calldatas = new bytes[](2);

        calldatas[0] = abi.encodeWithSelector(
            _votingEscrow.commit_smart_wallet_checker.selector,
            _checker
        );

        calldatas[1] = abi.encodeWithSelector(_votingEscrow.apply_smart_wallet_checker.selector);

        string memory description = "Test proposal";

        // pushing time a little bit forward
        vm.warp(block.timestamp + 3_600);

        vm.prank(_voter);

        uint256 proposalId = _siloGovernor.propose(
            targets,
            values,
            calldatas,
            description
        );

        uint256 snapshot = _siloGovernor.proposalSnapshot(proposalId);
        // pushing time to change a proposal to an active status
        vm.warp(snapshot + 3_600);

        vm.prank(_voter);
        _siloGovernor.castVote(proposalId, 1);

        vm.warp(snapshot + 365 * 24 * 3_600);

        _siloGovernor.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        vm.warp(block.timestamp + 3_600);

        _siloGovernor.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );
    }
}
