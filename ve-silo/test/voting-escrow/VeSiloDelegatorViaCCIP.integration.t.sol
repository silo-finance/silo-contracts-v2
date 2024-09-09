// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Client} from "chainlink-ccip/v0.8/ccip/libraries/Client.sol";
import {OwnableUpgradeable} from "openzeppelin5-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "openzeppelin5-upgradeable/proxy/utils/Initializable.sol";

import {AddrKey} from "common/addresses/AddrKey.sol";
import {VeSiloDelegatorViaCCIPDeploy} from "ve-silo/deploy/VeSiloDelegatorViaCCIPDeploy.s.sol";
import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {IVeSilo} from "ve-silo/contracts/voting-escrow/interfaces/IVeSilo.sol";
import {IVeSiloDelegatorViaCCIP} from "ve-silo/contracts/voting-escrow/interfaces/IVeSiloDelegatorViaCCIP.sol";
import {VeSiloDelegatorViaCCIP} from "ve-silo/contracts/voting-escrow/VeSiloDelegatorViaCCIP.sol";
import {ICCIPMessageSender, CCIPMessageSender} from "ve-silo/contracts/utils/CCIPMessageSender.sol";
import {IVotingEscrowCCIPRemapper} from "ve-silo/contracts/voting-escrow/interfaces/IVotingEscrowCCIPRemapper.sol";
import {VotingEscrowTest} from "./VotingEscrow.integration.t.sol";
import {ISmartWalletChecker} from "ve-silo/contracts/voting-escrow/interfaces/ISmartWalletChecker.sol";
import {ICCIPExtraArgsConfig} from "ve-silo/contracts/gauges/interfaces/ICCIPExtraArgsConfig.sol";
import {ICCIPGauge} from "ve-silo/contracts/gauges/interfaces/ICCIPGauge.sol";

// FOUNDRY_PROFILE=ve-silo-test forge test --mc VeSiloDelegatorViaCCIPTest --ffi -vvv
contract VeSiloDelegatorViaCCIPTest is IntegrationTest {
    IVeSiloDelegatorViaCCIP public veSiloDelegator;
    VotingEscrowTest public veTest;
    IVeSilo public votingEscrow;

    uint256 internal constant _FORKING_BLOCK_NUMBER = 201222490;
    uint64 internal constant _DS_CHAIN_SELECTOR = 5009297550715157269; // Ethereum

    address internal _localUser = makeAddr("localUser");
    address internal _votingEscrowCCIPRemapper = makeAddr("VotingEscrowCCIPRemapper");
    address internal _smartValletChecker = makeAddr("Smart wallet checker");
    address internal _childChainReceiver = makeAddr("Child chain receiver");
    address internal _deployer;
    address internal _link;
    address internal _timelock;

    event SentUserBalance(
        uint64 dstChainSelector,
        address localUser,
        address remoteUser,
        IVeSilo.Point userPoint,
        IVeSilo.Point totalSupplyPoint
    );

    event SentTotalSupply(uint64 dstChainSelector, IVeSilo.Point totalSupplyPoint);
    event MessageSentVaiCCIP(bytes32 messageId);
    event ChildChainReceiverUpdated(uint64 dstChainSelector, address receiver);
    event ExtraArgsUpdated(bytes extraArgs);

    function setUp() public {
        vm.createSelectFork(
            getChainRpcUrl(ARBITRUM_ONE_ALIAS),
            _FORKING_BLOCK_NUMBER
        );

        veTest = new VotingEscrowTest();
        veTest.deployVotingEscrowForTests();

        VeSiloDelegatorViaCCIPDeploy deploy = new VeSiloDelegatorViaCCIPDeploy();
        deploy.disableDeploymentsSync();

        _mockCallsBeforeDeploy();

        veTest.getVeSiloTokens(_localUser, 1 ether, block.timestamp + 365 * 24 * 3600);

        veSiloDelegator = deploy.run();

        votingEscrow = IVeSilo(getAddress(VeSiloContracts.VOTING_ESCROW));

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        _deployer = vm.addr(deployerPrivateKey);
        _timelock = VeSiloDeployments.get(VeSiloContracts.TIMELOCK_CONTROLLER, getChainAlias());
        _link = getAddress(AddrKey.LINK);
    }

    function testShouldFailToReinitialize() public {
        address newOwner = makeAddr("newOwner");

        VeSiloDelegatorViaCCIP delegatorProxy = VeSiloDelegatorViaCCIP(address(veSiloDelegator));

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        delegatorProxy.initialize(newOwner);

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        vm.prank(_timelock);
        delegatorProxy.initialize(newOwner);

        address implementation = VeSiloDeployments.get(VeSiloContracts.VE_SILO_DELEGATOR_VIA_CCIP, getChainAlias());

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        VeSiloDelegatorViaCCIP(implementation).initialize(newOwner);

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        vm.prank(_timelock);
        VeSiloDelegatorViaCCIP(implementation).initialize(newOwner);
    }

    function testChildChainReceiveUpdatePermissions() public {
        vm.expectRevert(abi.encodeWithSelector(
            OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
            address(this)
        ));

        veSiloDelegator.setChildChainReceiver(_DS_CHAIN_SELECTOR, _childChainReceiver);

        _setChildChainReceiver();
    }

    function testSetExtraArgs() public {
        bytes memory anyExtraArgs = abi.encodePacked("any extra args");

        ICCIPExtraArgsConfig delegator = ICCIPExtraArgsConfig(address(veSiloDelegator));

        // Test permissions and configuration
        vm.expectRevert(abi.encodeWithSelector(
            OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
            address(this)
        ));

        delegator.setExtraArgs(anyExtraArgs);

        vm.expectEmit(false, false, false, true);
        emit ICCIPExtraArgsConfig.ExtraArgsUpdated(anyExtraArgs);

        vm.prank(_timelock);
        delegator.setExtraArgs(anyExtraArgs);

        assertEq(
            keccak256(delegator.extraArgs()),
            keccak256(anyExtraArgs),
            "Args did not match after the config"
        );

        // Test the message construction
        bytes memory data;

        Client.EVM2AnyMessage memory message = CCIPMessageSender(address(veSiloDelegator)).getCCIPMessage(
            _childChainReceiver,
            data,
            ICCIPMessageSender.PayFeesIn.LINK
        );

        assertEq(keccak256(message.extraArgs), keccak256(anyExtraArgs), "Wrong args in the message");
    }

    function testUnsupportedChain() public {
        vm.expectRevert(abi.encodeWithSelector(
            IVeSiloDelegatorViaCCIP.ChainIsNotSupported.selector,
            _DS_CHAIN_SELECTOR
        ));

        veSiloDelegator.sendUserBalance(
            _localUser,
            _DS_CHAIN_SELECTOR,
            ICCIPMessageSender.PayFeesIn.Native
        );

        vm.expectRevert(abi.encodeWithSelector(
            IVeSiloDelegatorViaCCIP.ChainIsNotSupported.selector,
            _DS_CHAIN_SELECTOR
        ));

        veSiloDelegator.sendTotalSupply(
            _DS_CHAIN_SELECTOR,
            ICCIPMessageSender.PayFeesIn.Native
        );
    }

    function testSendUserBalanceNativeFee() public {
        _setChildChainReceiver();

        uint256 fee = veSiloDelegator.estimateSendUserBalance(
            _localUser,
            _DS_CHAIN_SELECTOR,
            ICCIPMessageSender.PayFeesIn.Native
        );

        vm.deal(_localUser, fee);

        _sendUserBalance(ICCIPMessageSender.PayFeesIn.Native, fee);
    }

    function testSendUserBalanceLINKFee() public {
        _setChildChainReceiver();

        uint256 fee = veSiloDelegator.estimateSendUserBalance(
            _localUser,
            _DS_CHAIN_SELECTOR,
            ICCIPMessageSender.PayFeesIn.LINK
        );

        deal(_link, _localUser, fee);

        vm.prank(_localUser);
        IERC20(_link).approve(address(veSiloDelegator), fee);

        _sendUserBalance(ICCIPMessageSender.PayFeesIn.LINK, fee);
    }

    function testSendTotalSupplyNativeFee() public {
        _setChildChainReceiver();

         uint256 fee = veSiloDelegator.estimateSendTotalSupply(
            _DS_CHAIN_SELECTOR,
            ICCIPMessageSender.PayFeesIn.Native
        );

        vm.deal(_localUser, fee);

        _sendTotalSupply(ICCIPMessageSender.PayFeesIn.Native, fee);
    }

    function testSendTotalSupplyLINKFee() public {
        _setChildChainReceiver();

         uint256 fee = veSiloDelegator.estimateSendTotalSupply(
            _DS_CHAIN_SELECTOR,
            ICCIPMessageSender.PayFeesIn.LINK
        );

        deal(_link, _localUser, fee);

        vm.prank(_localUser);
        IERC20(_link).approve(address(veSiloDelegator), fee);

        _sendTotalSupply(ICCIPMessageSender.PayFeesIn.LINK, fee);
    }

    function _sendTotalSupply(ICCIPMessageSender.PayFeesIn _payFeesIn, uint256 _fee) internal {
        uint totalSupplyEpoch = votingEscrow.epoch();
        IVeSilo.Point memory totalSupplyPoint = votingEscrow.point_history(totalSupplyEpoch);

        vm.expectEmit(false, false, true, true);
        emit SentTotalSupply(_DS_CHAIN_SELECTOR, totalSupplyPoint);

        vm.prank(_localUser);

        if (_payFeesIn == ICCIPMessageSender.PayFeesIn.Native) {
            veSiloDelegator.sendTotalSupply{value: _fee}(_DS_CHAIN_SELECTOR, _payFeesIn);
        } else {
            veSiloDelegator.sendTotalSupply(_DS_CHAIN_SELECTOR, _payFeesIn);
        }
    }

    function _setChildChainReceiver() internal {
        vm.expectEmit(false, false, true, true);
        emit ChildChainReceiverUpdated(_DS_CHAIN_SELECTOR, _childChainReceiver);

        vm.prank(_timelock);
        veSiloDelegator.setChildChainReceiver(_DS_CHAIN_SELECTOR, _childChainReceiver);
    }

    function _sendUserBalance(ICCIPMessageSender.PayFeesIn _payFeesIn, uint256 _fee) internal {
        uint userEpoch = votingEscrow.user_point_epoch(_localUser);
        IVeSilo.Point memory userPoint = votingEscrow.user_point_history(_localUser, userEpoch);

        // always send total supply along with a user update
        uint totalSupplyEpoch = votingEscrow.epoch();
        IVeSilo.Point memory totalSupplyPoint = votingEscrow.point_history(totalSupplyEpoch);

        vm.expectEmit(false, false, false, true);
        emit SentUserBalance(
            _DS_CHAIN_SELECTOR,
            _localUser,
            _localUser,
            userPoint,
            totalSupplyPoint
        );

        vm.prank(_localUser);

        if (_payFeesIn == ICCIPMessageSender.PayFeesIn.Native) {
            veSiloDelegator.sendUserBalance{value: _fee}(
                _localUser,
                _DS_CHAIN_SELECTOR,
                _payFeesIn
            );
        } else {
            veSiloDelegator.sendUserBalance(
                _localUser,
                _DS_CHAIN_SELECTOR,
                _payFeesIn
            );
        }
    }

    function _mockCallsBeforeDeploy() internal {
        setAddress(VeSiloContracts.VOTING_ESCROW_REMAPPER, _votingEscrowCCIPRemapper);

        vm.mockCall(
            _smartValletChecker,
            abi.encodeWithSelector(ISmartWalletChecker.check.selector, _localUser),
            abi.encode(true)
        );

        vm.mockCall(
            _votingEscrowCCIPRemapper,
            abi.encodeWithSelector(IVotingEscrowCCIPRemapper.getRemoteUser.selector, _localUser, _DS_CHAIN_SELECTOR),
            abi.encode(address(0))
        );
    }
}
