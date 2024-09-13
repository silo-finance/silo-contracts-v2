// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Client} from "chainlink-ccip/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";
import {OwnableUpgradeable} from "openzeppelin5-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "openzeppelin5-upgradeable/proxy/utils/Initializable.sol";

import {IVeSilo} from "ve-silo/contracts/voting-escrow/interfaces/IVeSilo.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {ICCIPMessageSender} from "ve-silo/contracts/utils/CCIPMessageSender.sol";
import {VotingEscrowChildChainDeploy} from "ve-silo/deploy/VotingEscrowChildChainDeploy.s.sol";
import {IVotingEscrowChildChain} from "ve-silo/contracts/voting-escrow/interfaces/IVotingEscrowChildChain.sol";
import {IAny2EVMMessageReceiver} from "ve-silo/contracts/voting-escrow/interfaces/IVotingEscrowChildChain.sol";
import {VotingEscrowChildChain} from "ve-silo/contracts/voting-escrow/VotingEscrowChildChain.sol";

// FOUNDRY_PROFILE=ve-silo-test forge test --mc VotingEscrowChildChainTest --ffi -vvv
contract VotingEscrowChildChainTest is IntegrationTest {
    bytes32 internal constant _TEST_MESSAGE_ID = keccak256(abi.encodePacked(bytes("test message id")));
    uint256 internal constant _LOCKED_END_TEST = 1726099200;
    uint64 internal constant _TEST_CHAIN_SELECTOR = 1;

    IVeSilo.Point public tsTestPoint = IVeSilo.Point({
        bias: 2947469178042106200,
        slope: 95129375950,
        ts: 1695115404,
        blk: 4319390
    });

    IVeSilo.Point public uTestPoint = IVeSilo.Point({
        bias: 982489726003707468,
        slope: 31709791983,
        ts: 1695115404,
        blk: 4319390
    });

    IVotingEscrowChildChain internal _votingEscrowChild;

    address internal _router = makeAddr("CCIP Router");
    address internal _localUser = makeAddr("localUser");
    address internal _sender = makeAddr("Source chain sender");
    address internal _multisig = makeAddr("Multisig");
    address internal _deployer;

    event MessageReceived(bytes32 indexed messageId);
    event UserBalanceUpdated(address indexed user, uint256 lockedEnd, IVeSilo.Point userPoint);
    event TotalSupplyUpdated(IVeSilo.Point totalSupplyPoint);
    event MainChainSenderConfiguered(address sender);

    function setUp() public {
        VotingEscrowChildChainDeploy deploy = new VotingEscrowChildChainDeploy();
        deploy.disableDeploymentsSync();

        setAddress(AddrKey.CHAINLINK_CCIP_ROUTER, _router);
        setAddress(AddrKey.L2_MULTISIG, _multisig);

        _votingEscrowChild = deploy.run();

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        _deployer = vm.addr(deployerPrivateKey);
    }

    function testSetSourceChainSenderPermissions() public {
        vm.expectRevert(abi.encodeWithSelector(
            OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
            address(this)
        ));

        _votingEscrowChild.setSourceChainSender(_sender);

        _setSourceChainSender();
    }

    function testShouldFailToReinitialize() public {
        address newOwner = makeAddr("newOwner");

        VotingEscrowChildChain proxy = VotingEscrowChildChain(address(_votingEscrowChild));

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        proxy.initialize(newOwner);

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        vm.prank(_multisig);
        proxy.initialize(newOwner);

        VotingEscrowChildChain implementation = new VotingEscrowChildChain(
            address(1), // router
            1 // dst chain selector
        );

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        implementation.initialize(newOwner);

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        vm.prank(_multisig);
        implementation.initialize(newOwner);
    }

    function testReceiveBalanceAndTotalSupply() public {
        _setSourceChainSender();

        bytes memory data = balanceTransferData();

        Client.Any2EVMMessage memory ccipMessage = getCCIPMessage(data);

        vm.expectEmit(false, true, true, true);
        emit UserBalanceUpdated(
            _localUser,
            _LOCKED_END_TEST,
            uTestPoint
        );

        vm.expectEmit(false, false, false, true);
        emit TotalSupplyUpdated(tsTestPoint);

        vm.expectEmit(false, false, false, true);
        emit MessageReceived(_TEST_MESSAGE_ID);

        vm.prank(_router);
        _votingEscrowChild.ccipReceive(ccipMessage);

        vm.warp(tsTestPoint.ts);
        // `totalSupply` should be equal to the `point.bias` as `block.timestamp` is set to the `point.ts`
        assertEq(_votingEscrowChild.totalSupply(), uint256(int256(tsTestPoint.bias)), "Invalid total supply");
        // `balanceOf` should be equal to the `point.bias` as `block.timestamp` is set to the `point.ts`
        assertEq(_votingEscrowChild.balanceOf(_localUser), uint256(int256(uTestPoint.bias)), "Invalid user balance");
        assertEq(_votingEscrowChild.locked__end(_localUser), _LOCKED_END_TEST, "Locked end did not match");
    }

    function testReceiveTotalSupply() public {
        _setSourceChainSender();

        bytes memory data = totalSupplyTransferData();

        Client.Any2EVMMessage memory ccipMessage = getCCIPMessage(data);

        vm.expectEmit(false, false, false, true);
        emit TotalSupplyUpdated(tsTestPoint);

        vm.expectEmit(false, false, false, true);
        emit MessageReceived(_TEST_MESSAGE_ID);

        vm.prank(_router);
        _votingEscrowChild.ccipReceive(ccipMessage);

        vm.warp(tsTestPoint.ts);
        // `totalSupply` should be equal to the `point.bias` as `block.timestamp` is set to the `point.ts`
        assertEq(_votingEscrowChild.totalSupply(), uint256(int256(tsTestPoint.bias)), "Invalid total supply");
        assertEq(_votingEscrowChild.balanceOf(_localUser), 0, "Invalid user balance");
        assertEq(_votingEscrowChild.locked__end(_localUser), 0, "Locked end did not match");
    }

    function testMessageOrigins() public {
        uint64 wrongChain = type(uint64).max;
        bytes memory emptyData;
        
        Client.Any2EVMMessage memory ccipMessage = Client.Any2EVMMessage({
            messageId: bytes32(uint256(1)),
            sourceChainSelector: wrongChain,
            sender: abi.encode(address(1)),
            data: emptyData,
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        vm.expectRevert(IVotingEscrowChildChain.UnsupportedSourceChain.selector);

        vm.prank(_router);
        _votingEscrowChild.ccipReceive(ccipMessage);

        ccipMessage.sourceChainSelector = _TEST_CHAIN_SELECTOR;

        vm.expectRevert(IVotingEscrowChildChain.UnauthorizedSender.selector);

        vm.prank(_router);
        _votingEscrowChild.ccipReceive(ccipMessage);
    }

    function testMessageType() public {
        _setSourceChainSender();

        bytes memory data = wrongCodeData();

        Client.Any2EVMMessage memory ccipMessage = getCCIPMessage(data);

        // Conversion into non-existent enum type
        vm.expectRevert();

        vm.prank(_router);
        _votingEscrowChild.ccipReceive(ccipMessage);
    }

    function getCCIPMessage(bytes memory _data)
        public
        view
        returns (Client.Any2EVMMessage memory ccipMessage)
    {
        ccipMessage = Client.Any2EVMMessage({
            messageId: _TEST_MESSAGE_ID,
            sourceChainSelector: _TEST_CHAIN_SELECTOR,
            sender: abi.encode(_sender),
            data: _data,
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });
    }

    function balanceTransferData() public pure returns (bytes memory data) {
        // solhint-disable-next-line max-line-length
        data = hex"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000004b83cc4a15e13b84de509abc40893e1b5826ca420000000000000000000000000000000000000000000000000000000066e22f000000000000000000000000000000000000000000000000000da2813349ebfe4c00000000000000000000000000000000000000000000000000000007620d06ef000000000000000000000000000000000000000000000000000000006509688c000000000000000000000000000000000000000000000000000000000041e89e00000000000000000000000000000000000000000000000028e78399df9cc15800000000000000000000000000000000000000000000000000000016262714ce000000000000000000000000000000000000000000000000000000006509688c000000000000000000000000000000000000000000000000000000000041e89e";
    }

    function totalSupplyTransferData() public pure returns (bytes memory data) {
        // solhint-disable-next-line max-line-length
        data = hex"000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000028e78399df9cc15800000000000000000000000000000000000000000000000000000016262714ce000000000000000000000000000000000000000000000000000000006509688c000000000000000000000000000000000000000000000000000000000041e89e";
    }

    function wrongCodeData() public pure returns (bytes memory data) {
        // solhint-disable-next-line max-line-length
        data = hex"000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000028e78399df9cc15800000000000000000000000000000000000000000000000000000016262714ce000000000000000000000000000000000000000000000000000000006509688c000000000000000000000000000000000000000000000000000000000041e89e";
    }

    function _setSourceChainSender() internal {
        vm.expectEmit(false, false, false, true);
        emit MainChainSenderConfiguered(_sender);

        vm.prank(_multisig);
        _votingEscrowChild.setSourceChainSender(_sender);
    }
}
