// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Address} from "openzeppelin5/utils/Address.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";
import {Client} from "chainlink-ccip/v0.8/ccip/libraries/Client.sol";

import {IVeSilo} from "ve-silo/contracts/voting-escrow/interfaces/IVeSilo.sol";
import {IVotingEscrowCCIPRemapper} from "ve-silo/contracts/voting-escrow/interfaces/IVotingEscrowCCIPRemapper.sol";
import {ICCIPExtraArgsConfig} from "ve-silo/contracts/gauges/interfaces/ICCIPExtraArgsConfig.sol";
import {IVeSiloDelegatorViaCCIP} from "ve-silo/contracts/voting-escrow/interfaces/IVeSiloDelegatorViaCCIP.sol";
import {CCIPMessageSender, ICCIPMessageSender} from "ve-silo/contracts/utils/CCIPMessageSender.sol";

/// @title VeSilo delegator via CCIP
contract VeSiloDelegatorViaCCIP is CCIPMessageSender, Ownable2Step, Initializable, IVeSiloDelegatorViaCCIP {
    // solhint-disable var-name-mixedcase
    IVeSilo public immutable VOTING_ESCROW;
    IVotingEscrowCCIPRemapper public immutable REMAPPER;
    // solhint-enable var-name-mixedcase

    mapping(uint64 dstChainId => address receiver) public childChainReceivers;

    /// @param votingEscrow VeSilo address
    /// @param remapper VeSilo remapper via CCIP
    /// @param router CCIP router
    /// @param link LINK token address
    constructor(
        IVeSilo votingEscrow,
        IVotingEscrowCCIPRemapper remapper,
        address router,
        address link
    ) CCIPMessageSender(router, link) Ownable(msg.sender) {
        VOTING_ESCROW = votingEscrow;
        REMAPPER = remapper;

        // Locks an implementation, preventing any future reinitialization
        _disableInitializers();
        _transferOwnership(address(0));
    }

    /// @inheritdoc IVeSiloDelegatorViaCCIP
    function sendUserBalance(
        address _localUser,
        uint64 _dstChainSelector,
        PayFeesIn _payFeesIn
    ) external payable {
        address childChainReceiver = childChainReceivers[_dstChainSelector];

        if (childChainReceiver == address(0)) revert ChainIsNotSupported(_dstChainSelector);

        address remoteUser;
        IVeSilo.Point memory tsPoint;
        IVeSilo.Point memory uPoint;
        bytes memory data;

        (remoteUser, data, tsPoint, uPoint) = _getBalanceAndTotalSupplyData(_localUser, _dstChainSelector);

        _sendMesssageViaCCIP(
            _dstChainSelector,
            childChainReceiver,
            data,
            _payFeesIn
        );

        _sendBackETHLeftover();

        emit SentUserBalance(
            _dstChainSelector,
            _localUser,
            remoteUser,
            uPoint,
            tsPoint
        );
    }

    /// @inheritdoc IVeSiloDelegatorViaCCIP
    function sendTotalSupply(uint64 _dstChainSelector, PayFeesIn _payFeesIn) external payable {
        address childChainReceiver = childChainReceivers[_dstChainSelector];

        if (childChainReceiver == address(0)) revert ChainIsNotSupported(_dstChainSelector);

        uint256 totalSupplyEpoch = VOTING_ESCROW.epoch();
        IVeSilo.Point memory tsPoint = VOTING_ESCROW.point_history(totalSupplyEpoch);

        // Total supply point may only change if none has checkpointed after the current week has started.
        // If that's the case the checkpoint is performed at this point, before bridging the total supply.
        // If last checkpoint rounded to weeks + one week is still behind the block timestamp, then it has expired.
        bool expired;
        
        unchecked {
            // We will never overflow as `tsPoint.ts` will store a block.timestamp value
            // which will never be greater than type(uint256).max - 1 weeks
            expired = tsPoint.ts / 1 weeks * 1 weeks + 1 weeks < block.timestamp;
        }

        if (expired) {
            VOTING_ESCROW.checkpoint();
        }

        bytes memory data = _getTotalSupplyData(totalSupplyEpoch);

        _sendMesssageViaCCIP(
            uint64(_dstChainSelector),
            childChainReceiver,
            data,
            _payFeesIn
        );

        _sendBackETHLeftover();

        emit SentTotalSupply(_dstChainSelector, tsPoint);
    }

    /// @inheritdoc IVeSiloDelegatorViaCCIP
    function setChildChainReceiver(uint64 _dstChainSelector, address _receiver) external onlyOwner {
        if (_dstChainSelector == 0) revert ChainIdCantBeZero();

        childChainReceivers[_dstChainSelector] = _receiver;

        emit ChildChainReceiverUpdated(uint64(_dstChainSelector), _receiver);
    }
    
    /// @inheritdoc ICCIPExtraArgsConfig
    function setExtraArgs(bytes calldata _extraArgs) external onlyOwner {
        extraArgs = _extraArgs;

        emit ExtraArgsUpdated(_extraArgs);
    }

    /// @inheritdoc IVeSiloDelegatorViaCCIP
    function estimateSendUserBalance(
        address _localUser,
        uint64 _dstChainSelector,
        ICCIPMessageSender.PayFeesIn _payFeesIn
    ) external view returns (uint256 fee) {
        address childChainReceiver = childChainReceivers[_dstChainSelector];

        if (childChainReceiver == address(0)) revert ChainIsNotSupported(_dstChainSelector);

        (,bytes memory data,,) = _getBalanceAndTotalSupplyData(_localUser, _dstChainSelector);
        Client.EVM2AnyMessage memory ccipMessage = getCCIPMessage(childChainReceiver, data, _payFeesIn);
        fee = _calculateFee(_dstChainSelector, ccipMessage);
    }

    /// @inheritdoc IVeSiloDelegatorViaCCIP
    function estimateSendTotalSupply(
        uint64 _dstChainSelector,
        PayFeesIn _payFeesIn
    ) external view returns (uint256 fee) {
        address childChainReceiver = childChainReceivers[_dstChainSelector];

        if (childChainReceiver == address(0)) revert ChainIsNotSupported(_dstChainSelector);

        uint256 totalSupplyEpoch = VOTING_ESCROW.epoch();
        bytes memory data = _getTotalSupplyData(totalSupplyEpoch);
        Client.EVM2AnyMessage memory ccipMessage = getCCIPMessage(childChainReceiver, data, _payFeesIn);
        fee = _calculateFee(_dstChainSelector, ccipMessage);
    }

    function initialize(address _timelock) public initializer {
        _transferOwnership(_timelock);
    }

    /// @notice Send back any ETH leftover to the `msg.sender`
    function _sendBackETHLeftover() internal {
        uint256 balance = address(this).balance;

        if (balance > 0) {
            Address.sendValue(payable(msg.sender), balance);
        }
    }

    /// @notice Encode a data for a user balance and a total supply transfer
    /// @param _localUser Local user address
    /// @param _dstChainSelector Destination chain selector
    /// @return remoteUser Remote user address
    /// @return data Encoded data to send via CCIP
    /// @return tsPoint VeSilo total supply point history
    /// @return uPoint VeSilo user balance point history
    function _getBalanceAndTotalSupplyData(
        address _localUser,
        uint64 _dstChainSelector
    )
        internal
        view
        returns (
            address remoteUser,
            bytes memory data,
            IVeSilo.Point memory tsPoint,
            IVeSilo.Point memory uPoint
        )
    {
        uint256 userEpoch = VOTING_ESCROW.user_point_epoch(_localUser);
        uPoint = VOTING_ESCROW.user_point_history(_localUser, userEpoch);

        uint256 lockedEnd = VOTING_ESCROW.locked__end(_localUser);

        // always send total supply along with a user update
        uint256 totalSupplyEpoch = VOTING_ESCROW.epoch();
        tsPoint = VOTING_ESCROW.point_history(totalSupplyEpoch);

        address remappedAddress = REMAPPER.getRemoteUser(_localUser, _dstChainSelector);
        remoteUser = remappedAddress != address(0) ? remappedAddress : _localUser;

        data = abi.encode(
            MessageType.BalanceAndTotalSupply,
            remoteUser,
            lockedEnd,
            uPoint,
            tsPoint
        );
    }

    /// @notice Encode a data for a total supply transfer
    /// @return data Encoded data to send via CCIP
    function _getTotalSupplyData(uint256 totalSupplyEpoch) internal view returns (bytes memory data) {
        IVeSilo.Point memory tsPoint = VOTING_ESCROW.point_history(totalSupplyEpoch);

        data = abi.encode(MessageType.TotalSupply, tsPoint);
    }
}
