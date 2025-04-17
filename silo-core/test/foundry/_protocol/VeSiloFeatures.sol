// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {IERC20} from "openzeppelin5/token/ERC20/ERC20.sol";
import {StdStorage, stdStorage} from "forge-std/StdStorage.sol";

import {IGaugeAdder} from "ve-silo/contracts/gauges/interfaces/IGaugeAdder.sol";
import {IFeesManager} from "ve-silo/contracts/silo-tokens-minter/interfaces/IFeesManager.sol";
import {IGaugeController} from "ve-silo/contracts/gauges/interfaces/IGaugeController.sol";
import {ISiloLiquidityGauge} from "ve-silo/contracts/gauges/interfaces/ISiloLiquidityGauge.sol";
import {CommonSiloIntegration} from "./CommonSiloIntegration.sol";

contract VeSiloFeatures is CommonSiloIntegration {
    using stdStorage for StdStorage;

    // Ethereum
    bytes32 constant internal _BALANCER_POOL_ID = 0x9cc64ee4cb672bc04c54b00a37e1ed75b2cc19dd0002000000000000000004c1;
    uint256 internal constant _WEIGHT_CAP = 1e18;
    uint256 internal constant _WEEK = 604800;
    uint256 internal constant _BPS_MAX = 1e4;
    uint256 internal constant _DAO_FEE = 1e3; // 10%
    uint256 internal constant _DEPLOYER_FEE = 2e3; // 20%

    function _whiteListUser(address _user) internal {
        vm.prank(_deployer);
        smartWalletChecker.allowlistAddress(_user);
    }

    function _configureSmartWalletChecker() internal {
        vm.prank(address(timelock));
        veSilo.commit_smart_wallet_checker(address(smartWalletChecker));

        vm.prank(address(timelock));
        veSilo.apply_smart_wallet_checker();
    }

    function _createGauge(address _shareToken) internal returns (address gauge) {
        vm.prank(_deployer);
        gauge = factory.create(_WEIGHT_CAP, _shareToken);
        vm.label(gauge, "Gauge");
    }

    function _checkpointUsers(ISiloLiquidityGauge _gauge) internal {
        assertEq(_gauge.integrate_fraction(_bob), 0, "Should not have earned incentives");

        vm.warp(block.timestamp + _WEEK + 1);

        vm.prank(_bob);
        _gauge.user_checkpoint(_bob);

        assertTrue(_gauge.integrate_fraction(_bob) != 0, "Should have earned incentives");
    }

    function _getVotingPower(address _user, uint256 _siloToLock) internal returns (uint256 votingPower){
        vm.prank(_user);
        _siloToken.approve(address(veSilo), _siloToLock);

        uint256 unlockTime = block.timestamp + 365 * 24 * 3600;

        vm.prank(_user);
        veSilo.create_lock(_siloToLock, unlockTime);

        votingPower = veSilo.balanceOf(_user);
    }

    // solhint-disable-next-line function-max-lines
    function _executeProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas
    )
        internal
    {
        string memory description = "Test proposal";

        // pushing time a little bit forward
        vm.warp(block.timestamp + 3_600);

        vm.prank(_bob);

        uint256 proposalId = siloGovernor.propose(
            targets,
            values,
            calldatas,
            description
        );

        uint256 snapshot = siloGovernor.proposalSnapshot(proposalId);
        // pushing time to change a proposal to an active status
        vm.warp(snapshot + 3_600);

        vm.prank(_bob);
        siloGovernor.castVote(proposalId, 1);

        vm.warp(snapshot + 1 weeks + 1 seconds);

        siloGovernor.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        vm.warp(block.timestamp + 3_600);

        siloGovernor.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );
    }

    function _addGauge(address _gauge) internal {
        address[] memory targets = new address[](6);
        targets[0] = address(gaugeController);
        targets[1] = address(gaugeController);
        targets[2] = address(gaugeAdder);
        targets[3] = address(gaugeAdder);
        targets[4] = address(gaugeAdder);
        targets[5] = address(gaugeAdder);

        // Empty values
        uint256[] memory values = new uint256[](6);

        // Functions inputs
        bytes[] memory calldatas = new bytes[](6);
        
        string memory gaugeTypeName = new string(64);
        gaugeTypeName = "Mainnet gauge";
        calldatas[0] = abi.encodeWithSignature("add_type(string,uint256)", gaugeTypeName, 1e18);
        calldatas[1] = abi.encodeCall(IGaugeController.set_gauge_adder, address(gaugeAdder));
        calldatas[2] = abi.encodePacked(Ownable2Step.acceptOwnership.selector);
        calldatas[3] = abi.encodeCall(IGaugeAdder.addGaugeType, gaugeTypeName);
        calldatas[4] = abi.encodeCall(IGaugeAdder.setGaugeFactory, (factory, gaugeTypeName));
        calldatas[5] = abi.encodeCall(IGaugeAdder.addGauge, (address(_gauge), gaugeTypeName));

        _executeProposal(targets, values, calldatas);

        assertEq(gaugeController.n_gauge_types(), 1, "An invalid number of the gauge types");
        assertEq(gaugeController.n_gauges(), 1, "Should be 1 gauge in the gaugeController");
    }

    function _voteForGauge(address _gauge) internal {
        vm.prank(_bob);
        gaugeController.vote_for_gauge_weights(_gauge, 10000);
    }

    function _setVeSiloFees() internal {
        vm.prank(_deployer);
        IFeesManager(address(mainnetMinter)).setFees(_DAO_FEE, _DEPLOYER_FEE);
    }

    function _verifyClaimable(ISiloLiquidityGauge _gauge) internal {
        vm.warp(block.timestamp + _WEEK + 1);

        uint256 claimableTotal;
        uint256 claimableTokens;
        uint256 feeDao;
        uint256 feeDeployer;

        claimableTotal = _gauge.claimable_tokens(_bob);
        (claimableTokens, feeDao, feeDeployer) = _gauge.claimable_tokens_with_fees(_bob);

        assertTrue(claimableTotal == (claimableTokens + feeDao + feeDeployer));

        uint256 expectedFeeDao = claimableTotal * _DAO_FEE / _BPS_MAX;
        uint256 expectedFeeDeployer = claimableTotal * _DEPLOYER_FEE / _BPS_MAX;
        uint256 expectedToReceive = claimableTotal - expectedFeeDao - expectedFeeDeployer;

        assertEq(expectedFeeDao, feeDao, "Wrong DAO fee");
        assertEq(expectedFeeDeployer, feeDeployer, "Wrong deployer fee");
        assertEq(expectedToReceive, claimableTokens, "Wrong number of the user tokens");
    }

    function _getIncentives(address _gauge) internal {
        _getUserIncentives(_bob, _gauge);
    }

    function _getUserIncentives(address _user, address _gauge) internal {
        IERC20 siloToken = IERC20(getAddress(SILO_TOKEN));

        assertEq(siloToken.balanceOf(_user), 0);

        vm.prank(_user);
        mainnetMinter.setMinterApproval(_user, true);
        vm.prank(_user);
        mainnetMinter.mintFor(_gauge, _user);

        assertTrue(siloToken.balanceOf(_user) != 0);

        uint256 totalMinted = mainnetMinter.minted(_user, _gauge);
        uint256 expectedMinted = totalMinted - (totalMinted * 10 / 100 + totalMinted * 20 / 100);
        uint256 mintedToUser = mainnetMinter.mintedToUser(_user, _gauge);

        assertEq(mintedToUser, expectedMinted, "Counters of minted tokens did not mutch");
    }

    function _activeteBlancerTokenAdmin() internal {
        stdstore
            .target(getAddress(SILO_TOKEN))
            .sig(Ownable.owner.selector)
            .checked_write(address(balancerTokenAdmin));

        vm.prank(_deployer);
        balancerTokenAdmin.activate();
    }
}
