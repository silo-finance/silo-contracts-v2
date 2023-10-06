// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {VotingEscrowRemapperDeploy} from "ve-silo/deploy/VotingEscrowRemapperDeploy.s.sol";
import {IVeSilo} from "ve-silo/contracts/voting-escrow/interfaces/IVeSilo.sol";
import {VotingEscrowTest} from "./VotingEscrow.integration.t.sol";
import {ISmartWalletChecker} from "ve-silo/contracts/voting-escrow/interfaces/ISmartWalletChecker.sol";
import {IVotingEscrowCCIPRemapper} from "ve-silo/contracts/voting-escrow/interfaces/IVotingEscrowCCIPRemapper.sol";
import {VeSiloDelegatorViaCCIPDeploy} from "ve-silo/deploy/VeSiloDelegatorViaCCIPDeploy.s.sol";
import {IVeSiloDelegatorViaCCIP} from "ve-silo/contracts/voting-escrow/interfaces/IVeSiloDelegatorViaCCIP.sol";
import {ICCIPMessageSender} from "ve-silo/contracts/utils/CCIPMessageSender.sol";

// FOUNDRY_PROFILE=ve-silo forge test --mc VotingEscrowRemapperTest --ffi -vvv
contract VotingEscrowRemapperTest is IntegrationTest {
    uint64 internal constant _DS_CHAIN_SELECTOR = 12532609583862916517; // Polygon Mumbai

    bytes32 internal constant _MESSAGE_ID_REMAP_ETH =
        0x6033df476de5e97423bc4d9e61a6496f22496118f6c216854e4b85607b69675e;
    bytes32 internal constant _MESSAGE_ID_REMAP_LINK =
        0x4c90654f822920121a60d48aee7c073b6f68611d494417cac5609ab68338cec9;
    bytes32 internal constant _MESSAGE_ID_CLEAR1_ETH =
        0x2c3014a32205f7644e12c22f2234cea2d61c307610e37274a73cd928a4d56809;
    bytes32 internal constant _MESSAGE_ID_CLEAR2_ETH =
        0x3f2b2b53e39b21c1ce78fd5a63b0a6d2a3c68a6645f0f15b13aa0a3cf66ba9b9;
    bytes32 internal constant _MESSAGE_ID_CLEAR1_LINK =
        0xec0255073ee9ba68934c64e58667c5d90809d4b7ae026cf41e94b88ba500df42;
    bytes32 internal constant _MESSAGE_ID_CLEAR2_LINK =
        0x9928f6bbde7a1ef6d4f282ec577fee40db396515598f54fdbde1b2d587db2d0c;

    IVeSiloDelegatorViaCCIP public veSiloDelegator;
    IVotingEscrowCCIPRemapper public remapper;
    VotingEscrowTest public veTest;
    IVeSilo public votingEscrow;

    uint256 internal constant _FORKING_BLOCK_NUMBER = 4325800;

    address internal _localUser = makeAddr("localUser");
    address internal _remoteUser = makeAddr("remoteUser");
    address internal _childChainReceiver = makeAddr("Child chain receiver");
    address internal _smartValletChecker = makeAddr("Smart wallet checker");
    address internal _deployer;
    address internal _link;

    event SentUserBalance(
        uint64 dstChainSelector,
        address localUser,
        address remoteUser,
        IVeSilo.Point userPoint,
        IVeSilo.Point totalSupplyPoint
    );

    event MessageSentVaiCCIP(bytes32 messageId);
    event VeSiloDelegatorUpdated(IVeSiloDelegatorViaCCIP delegator);
    event ChildChainReceiverUpdated(uint64 dstChainSelector, address receiver);

    function setUp() public {
        vm.createSelectFork(
            getChainRpcUrl(SEPOLIA_ALIAS),
            _FORKING_BLOCK_NUMBER
        );

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        _deployer = vm.addr(deployerPrivateKey);

        veTest = new VotingEscrowTest();
        veTest.deployVotingEscrowForTests();

        VotingEscrowRemapperDeploy deploy = new VotingEscrowRemapperDeploy();
        deploy.disableDeploymentsSync();

        vm.mockCall(
            _smartValletChecker,
            abi.encodeCall(ISmartWalletChecker.check, _localUser),
            abi.encode(true)
        );

        veTest.getVeSiloTokens(_localUser, 1 ether, block.timestamp + 365 * 24 * 3600);

        remapper = deploy.run();

        votingEscrow = IVeSilo(getAddress(VeSiloContracts.VOTING_ESCROW));

        _link = getAddress(AddrKey.LINK);

        VeSiloDelegatorViaCCIPDeploy delegatorDeploy = new VeSiloDelegatorViaCCIPDeploy();
        veSiloDelegator = delegatorDeploy.run();
    }

    function testChildChainReceiveUpdatePermissions() public {
        vm.expectRevert("Ownable: caller is not the owner");
        remapper.setVeSiloDelegator(veSiloDelegator);

        _setVeSiloDelegator();
    }

    function testSetNetworkRemappingNativeFee() public {
        _setVeSiloDelegator();
        _setChildChainReceiver();
        _setNetworkRemappingNative();
    }

    function testSetNetworkRemappingLINKFee() public {
        _setVeSiloDelegator();
        _setChildChainReceiver();
        _setNetworkRemappingLINK();
    }

    function testClearNetworkRemappingNative() public {
        _setVeSiloDelegator();
        _setChildChainReceiver();
        _setNetworkRemappingNative();

        uint256 fee = veSiloDelegator.estimateSendUserBalance(
            _localUser,
            _DS_CHAIN_SELECTOR,
            ICCIPMessageSender.PayFeesIn.Native
        );

        // we will have two transfers
        fee *= 2;

        vm.deal(_localUser, fee);

        bytes32[2] memory messagesIds;
        messagesIds[0] = _MESSAGE_ID_CLEAR1_ETH;
        messagesIds[1] = _MESSAGE_ID_CLEAR2_ETH;

        _clearNetworkRemapping(ICCIPMessageSender.PayFeesIn.Native, fee, messagesIds);
    }

    function testClearNetworkRemappingLINK() public {
        _setVeSiloDelegator();
        _setChildChainReceiver();
        _setNetworkRemappingLINK();

        uint256 fee = veSiloDelegator.estimateSendUserBalance(
            _localUser,
            _DS_CHAIN_SELECTOR,
            ICCIPMessageSender.PayFeesIn.LINK
        );

        // we will have two transfers
        fee *= 2;

        deal(_link, _localUser, fee);

        vm.prank(_localUser);
        IERC20(_link).approve(address(remapper), fee);

        bytes32[2] memory messagesIds;
        messagesIds[0] = _MESSAGE_ID_CLEAR1_LINK;
        messagesIds[1] = _MESSAGE_ID_CLEAR2_LINK;

        _clearNetworkRemapping(ICCIPMessageSender.PayFeesIn.LINK, fee, messagesIds);
    }

    function _setNetworkRemappingNative() internal {
        uint256 fee = veSiloDelegator.estimateSendUserBalance(
            _localUser,
            _DS_CHAIN_SELECTOR,
            ICCIPMessageSender.PayFeesIn.Native
        );

        vm.deal(_localUser, fee);

        _setNetworkRemapping(ICCIPMessageSender.PayFeesIn.Native, fee, _MESSAGE_ID_REMAP_ETH);
    }

    function _setNetworkRemappingLINK() internal {
        uint256 fee = veSiloDelegator.estimateSendUserBalance(
            _localUser,
            _DS_CHAIN_SELECTOR,
            ICCIPMessageSender.PayFeesIn.LINK
        );

        deal(_link, _localUser, fee);

        vm.prank(_localUser);
        IERC20(_link).approve(address(remapper), fee);

        _setNetworkRemapping(ICCIPMessageSender.PayFeesIn.LINK, fee, _MESSAGE_ID_REMAP_LINK);
    }

    // solhint-disable-next-line function-max-lines
    function _clearNetworkRemapping(
        ICCIPMessageSender.PayFeesIn _payFeesIn,
        uint256 _fee,
        bytes32[2] memory _messagesIds
    ) internal {
        uint userEpoch = votingEscrow.user_point_epoch(_localUser);
        IVeSilo.Point memory userPoint = votingEscrow.user_point_history(_localUser, userEpoch);

        // always send total supply along with a user update
        uint totalSupplyEpoch = votingEscrow.epoch();
        IVeSilo.Point memory totalSupplyPoint = votingEscrow.point_history(totalSupplyEpoch);

        vm.expectEmit(false, false, false, true);
        emit MessageSentVaiCCIP(_messagesIds[0]);

        IVeSilo.Point memory emptyUserPoint;

        vm.expectEmit(false, false, false, true);
        emit SentUserBalance(
            _DS_CHAIN_SELECTOR,
            _remoteUser,
            _remoteUser,
            emptyUserPoint,
            totalSupplyPoint
        );

        vm.expectEmit(false, false, false, true);
        emit MessageSentVaiCCIP(_messagesIds[1]);

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
            remapper.clearNetworkRemapping{value: _fee}(
                _localUser,
                _DS_CHAIN_SELECTOR,
                _payFeesIn
            );
        } else {
            remapper.clearNetworkRemapping(
                _localUser,
                _DS_CHAIN_SELECTOR,
                _payFeesIn
            );
        }
    }

    function _setNetworkRemapping(
        ICCIPMessageSender.PayFeesIn _payFeesIn,
        uint256 _fee,
        bytes32 _messageId
    ) internal {
        uint userEpoch = votingEscrow.user_point_epoch(_localUser);
        IVeSilo.Point memory userPoint = votingEscrow.user_point_history(_localUser, userEpoch);

        // always send total supply along with a user update
        uint totalSupplyEpoch = votingEscrow.epoch();
        IVeSilo.Point memory totalSupplyPoint = votingEscrow.point_history(totalSupplyEpoch);

        vm.expectEmit(false, false, false, true);
        emit MessageSentVaiCCIP(_messageId);

        vm.expectEmit(false, false, false, true);
        emit SentUserBalance(
            _DS_CHAIN_SELECTOR,
            _localUser,
            _remoteUser,
            userPoint,
            totalSupplyPoint
        );

        vm.prank(_localUser);

        if (_payFeesIn == ICCIPMessageSender.PayFeesIn.Native) {
            remapper.setNetworkRemapping{value: _fee}(
                _localUser,
                _remoteUser,
                _DS_CHAIN_SELECTOR,
                _payFeesIn
            );
        } else {
            remapper.setNetworkRemapping(
                _localUser,
                _remoteUser,
                _DS_CHAIN_SELECTOR,
                _payFeesIn
            );
        }
    }

    function _setChildChainReceiver() internal {
        vm.expectEmit(false, false, true, true);
        emit ChildChainReceiverUpdated(_DS_CHAIN_SELECTOR, _childChainReceiver);

        vm.prank(_deployer);
        veSiloDelegator.setChildChainReceiver(_DS_CHAIN_SELECTOR, _childChainReceiver);
    }

    function _setVeSiloDelegator() internal {
        vm.expectEmit(false, false, false, true);
        emit VeSiloDelegatorUpdated(veSiloDelegator);

        vm.prank(_deployer);
        remapper.setVeSiloDelegator(veSiloDelegator);
    }
}
