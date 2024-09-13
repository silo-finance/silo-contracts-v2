// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

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

// FOUNDRY_PROFILE=ve-silo-test forge test --mc VotingEscrowRemapperTest --ffi -vvv
contract VotingEscrowRemapperTest is IntegrationTest {
    uint64 internal constant _DS_CHAIN_SELECTOR = 12532609583862916517; // Polygon Mumbai

    IVeSiloDelegatorViaCCIP public veSiloDelegator;
    IVotingEscrowCCIPRemapper public remapper;
    VotingEscrowTest public veTest;
    IVeSilo public votingEscrow;

    uint256 internal constant _FORKING_BLOCK_NUMBER = 4325800;

    address internal _localUser = makeAddr("localUser");
    address internal _remoteUser = makeAddr("remoteUser");
    address internal _childChainReceiver = makeAddr("Child chain receiver");
    address internal _smartValletChecker = makeAddr("Smart wallet checker");
    address internal _timelock = makeAddr("Timelock");
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

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
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

        setAddress(VeSiloContracts.TIMELOCK_CONTROLLER, _timelock);

        VeSiloDelegatorViaCCIPDeploy delegatorDeploy = new VeSiloDelegatorViaCCIPDeploy();
        veSiloDelegator = delegatorDeploy.run();
    }

    function testChildChainReceiveUpdatePermissions() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
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

        _clearNetworkRemapping(ICCIPMessageSender.PayFeesIn.Native, fee);
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

        _clearNetworkRemapping(ICCIPMessageSender.PayFeesIn.LINK, fee);
    }

    function _setNetworkRemappingNative() internal {
        uint256 fee = veSiloDelegator.estimateSendUserBalance(
            _localUser,
            _DS_CHAIN_SELECTOR,
            ICCIPMessageSender.PayFeesIn.Native
        );

        vm.deal(_localUser, fee);

        _setNetworkRemapping(ICCIPMessageSender.PayFeesIn.Native, fee);
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

        _setNetworkRemapping(ICCIPMessageSender.PayFeesIn.LINK, fee);
    }

    // solhint-disable-next-line function-max-lines
    function _clearNetworkRemapping(
        ICCIPMessageSender.PayFeesIn _payFeesIn,
        uint256 _fee
    ) internal {
        uint userEpoch = votingEscrow.user_point_epoch(_localUser);
        IVeSilo.Point memory userPoint = votingEscrow.user_point_history(_localUser, userEpoch);

        // always send total supply along with a user update
        uint totalSupplyEpoch = votingEscrow.epoch();
        IVeSilo.Point memory totalSupplyPoint = votingEscrow.point_history(totalSupplyEpoch);

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
        uint256 _fee
    ) internal {
        uint userEpoch = votingEscrow.user_point_epoch(_localUser);
        IVeSilo.Point memory userPoint = votingEscrow.user_point_history(_localUser, userEpoch);

        // always send total supply along with a user update
        uint totalSupplyEpoch = votingEscrow.epoch();
        IVeSilo.Point memory totalSupplyPoint = votingEscrow.point_history(totalSupplyEpoch);

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

        vm.prank(_timelock);
        veSiloDelegator.setChildChainReceiver(_DS_CHAIN_SELECTOR, _childChainReceiver);
    }

    function _setVeSiloDelegator() internal {
        vm.expectEmit(false, false, false, true);
        emit VeSiloDelegatorUpdated(veSiloDelegator);

        vm.prank(_deployer);
        remapper.setVeSiloDelegator(veSiloDelegator);
    }
}
