// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";
import {CCIPReceiver} from "chainlink-ccip/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "chainlink-ccip/v0.8/ccip/libraries/Client.sol";

import {IVeSilo} from "./interfaces/IVeSilo.sol";
import {IVotingEscrowChildChain} from "./interfaces/IVotingEscrowChildChain.sol";
import {IVeSiloDelegatorViaCCIP} from "./interfaces/IVeSiloDelegatorViaCCIP.sol";

/// @notice Child chain voting escrow.
/// Accept VeSilo from the main chain.
contract VotingEscrowChildChain is CCIPReceiver, Ownable2Step, Initializable, IVotingEscrowChildChain {
    // solhint-disable-next-line var-name-mixedcase
    uint64 public immutable SOURCE_CHAIN_SELECTOR;

    address public sourceChainSender;
    IVeSilo.Point public totalSupplyPoint;

    // solhint-disable-next-line var-name-mixedcase
    mapping(address user => uint256 endOfLockPeriod) public locked__end;
    mapping(address user => IVeSilo.Point) public userPoints;
    
    /// @param _router CCIP router
    /// @param _sourceChainSelector Source chain selector
    constructor(address _router, uint64 _sourceChainSelector) CCIPReceiver(_router) Ownable(msg.sender) {
        SOURCE_CHAIN_SELECTOR = _sourceChainSelector;

        // Locks an implementation, preventing any future reinitialization
        _disableInitializers();
        _transferOwnership(address(0));
    }

    /// @inheritdoc IVotingEscrowChildChain
    function withdraw(address _beneficiary) external onlyOwner {
        uint256 amount = address(this).balance;

        if (amount == 0) revert NothingToWithdraw();

        (bool sent, ) = _beneficiary.call{value: amount}("");
        if (!sent) revert FailedToWithdraw(_beneficiary, amount);
    }

    /// @inheritdoc IVotingEscrowChildChain
    function withdrawToken(address _beneficiary, address _token) external onlyOwner {
        uint256 amount = IERC20(_token).balanceOf(address(this));

        if (amount == 0) revert NothingToWithdraw();

        IERC20(_token).transfer(_beneficiary, amount);
    }

    /// @inheritdoc IVotingEscrowChildChain
    function setSourceChainSender(address _sourceChainSender) external onlyOwner {
        sourceChainSender = _sourceChainSender;

        emit MainChainSenderConfiguered(sourceChainSender);
    }

    /// @inheritdoc IVotingEscrowChildChain
    function balanceOf(address _user) external view returns (uint256 balance) {
        return getPointValue(userPoints[_user]);
    }

    /// @inheritdoc IVotingEscrowChildChain
    function totalSupply() external view returns (uint256 result) {
        return getPointValue(totalSupplyPoint);
    }

    function initialize(address _timelock) public initializer {
        _transferOwnership(_timelock);
    }

    /// @notice Calculates a `IVeSilo.Point` value
    /// @return value `IVeSilo.Point` value
    function getPointValue(IVeSilo.Point memory _p) public view returns (uint256 value) {
        int128 bias = _p.bias - (_p.slope * int128(uint128(block.timestamp - _p.ts)));

        return bias < 0 ? 0 : uint256(uint128(bias));
    }

    /// @notice Receive and process a CCIP message
    /// @param message CCIP message that may be a user balance and a total supply update or
    /// the total supply update only
    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        if (message.sourceChainSelector != SOURCE_CHAIN_SELECTOR) revert UnsupportedSourceChain();

        address sender = abi.decode(message.sender, (address));

        if (sender != sourceChainSender) revert UnauthorizedSender();

        bytes memory data = message.data;
        IVeSiloDelegatorViaCCIP.MessageType messageType;

        assembly { // solhint-disable-line no-inline-assembly
            messageType := mload(add(data, 32))
        }

        if (messageType == IVeSiloDelegatorViaCCIP.MessageType.BalanceAndTotalSupply) {
            _balanceAndTotalSupply(data);
        } else if (messageType == IVeSiloDelegatorViaCCIP.MessageType.TotalSupply) {
            _totalSupply(data);
        } else {
            // If the received message has a different message type than `IVeSiloDelegatorViaCCIP.MessageType`
            // EVM should revert: "Conversion into non-existent enum type". But we will leave a revert just in case.
            revert UnknownMessageType();
        }

        emit MessageReceived(message.messageId);
    }

    /// @notice Process a message that updates a user balance and a total supply
    /// @param _data received from the message
    function _balanceAndTotalSupply(bytes memory _data) internal {
        address payable user;
        uint256 lockedEnd;
        IVeSilo.Point memory uPoint;
        IVeSilo.Point memory tsPoint;

        (, user, lockedEnd, uPoint, tsPoint) = abi.decode(_data, (
            IVeSiloDelegatorViaCCIP.MessageType,
            address,
            uint256,
            IVeSilo.Point,
            IVeSilo.Point
        ));

        locked__end[user] = lockedEnd;
        userPoints[user] = uPoint;

        emit UserBalanceUpdated(user, lockedEnd, uPoint);

        totalSupplyPoint = tsPoint;

        emit TotalSupplyUpdated(tsPoint);
    }

    /// @notice Process a message that updates a total supply
    /// @param _data received from the message
    function _totalSupply(bytes memory _data) internal {
        IVeSilo.Point memory tsPoint;

        (, tsPoint) = abi.decode(_data, (
            IVeSiloDelegatorViaCCIP.MessageType,
            IVeSilo.Point
        ));

        totalSupplyPoint = tsPoint;

        emit TotalSupplyUpdated(tsPoint);
    }
}
