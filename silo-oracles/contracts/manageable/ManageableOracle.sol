// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Initializable} from "openzeppelin5-upgradeable/proxy/utils/Initializable.sol";

import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IManageableOracle} from "silo-oracles/contracts/interfaces/IManageableOracle.sol";
import {PendingAddress, PendingUint192, PendingLib} from "silo-vaults/contracts/libraries/PendingLib.sol";
import {Ownable1and2Steps} from "common/access/Ownable1and2Steps.sol";

/// @title ManageableOracle
/// @notice Oracle forwarder that allows updating the oracle address with time lock and owner approval
contract ManageableOracle is ISiloOracle, IManageableOracle, Ownable1and2Steps, Initializable {
    using PendingLib for PendingAddress;
    using PendingLib for PendingUint192;

    address public constant DEAD_ADDRESS = address(0xdead);

    /// @dev Minimum time lock duration
    uint32 public constant MIN_TIMELOCK = 1 days;

    /// @dev Maximum time lock duration
    uint32 public constant MAX_TIMELOCK = 7 days;

    /// @dev Quote token address (set during initialization)
    address public QUOTE_TOKEN;

    /// @dev Current oracle
    ISiloOracle public oracle;

    /// @dev Current time lock duration
    uint32 public timelock;

    /// @dev Pending oracle address
    PendingAddress public pendingOracle;

    /// @dev Pending time lock duration
    PendingUint192 public pendingTimelock;

    /// @dev Pending ownership transfer (address(0) means no pending transfer, address(0xdead) means pending renounce)
    PendingAddress public pendingOwnershipChange;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() Ownable1and2Steps(DEAD_ADDRESS) {
        // lock the implementation
        _transferOwnership(address(0));
        _disableInitializers();
    }

    /// @dev Modifier to check if timelock has elapsed
    modifier afterTimelock(uint64 _validAt) {
        require(_validAt != 0, NoPendingUpdate());
        require(block.timestamp >= _validAt, TimelockNotExpired());
        _;
    }

    /// @notice Initialize the ManageableOracle
    /// @param _oracle Initial oracle address
    /// @param _owner Address that will own the contract
    /// @param _timelock Initial time lock duration
    function initialize(ISiloOracle _oracle, address _owner, uint32 _timelock) external initializer {
        require(address(_oracle) != address(0), ZeroOracle());
        require(_owner != address(0), ZeroOwner());
        require(_timelock >= MIN_TIMELOCK && _timelock <= MAX_TIMELOCK, InvalidTimelock());

        QUOTE_TOKEN = _oracle.quoteToken();
        oracle = _oracle;
        timelock = _timelock;

        _transferOwnership(_owner);

        emit OracleUpdated(_oracle);
        emit TimelockUpdated(_timelock);
    }

    /// @inheritdoc IManageableOracle
    function proposeOracle(ISiloOracle _oracle) external virtual onlyOwner {
        require(pendingOracle.validAt == 0, PendingUpdate());
        require(address(_oracle) != address(0), ZeroOracle());
        require(_oracle.quoteToken() == QUOTE_TOKEN, QuoteTokenMustBeTheSame());

        pendingOracle.update(address(_oracle), timelock);

        emit OracleProposed(_oracle, pendingOracle.validAt);
    }

    /// @inheritdoc IManageableOracle
    function proposeTimelock(uint32 _timelock) external virtual onlyOwner {
        require(pendingTimelock.validAt == 0, PendingUpdate());
        require(_timelock >= MIN_TIMELOCK && _timelock <= MAX_TIMELOCK, InvalidTimelock());

        pendingTimelock.update(uint192(_timelock), timelock);

        emit TimelockProposed(_timelock, pendingTimelock.validAt);
    }

    /// @inheritdoc IManageableOracle
    function acceptOracle() external virtual onlyOwner afterTimelock(pendingOracle.validAt) {
        oracle = ISiloOracle(pendingOracle.value);
        _resetPendingAddress(pendingOracle);
        emit OracleUpdated(oracle);
    }

    /// @inheritdoc IManageableOracle
    function acceptTimelock() external virtual onlyOwner afterTimelock(pendingTimelock.validAt) {
        timelock = uint32(pendingTimelock.value);
        _resetPendingUint192(pendingTimelock);
        emit TimelockUpdated(timelock);
    }

    /// @inheritdoc IManageableOracle
    function cancelOracle() external virtual onlyOwner {
        require(pendingOracle.validAt != 0, NoPendingUpdateToCancel());

        _resetPendingAddress(pendingOracle);
        emit OracleProposalCanceled();
    }

    /// @inheritdoc IManageableOracle
    function cancelTimelock() external virtual onlyOwner {
        require(pendingTimelock.validAt != 0, NoPendingUpdateToCancel());

        _resetPendingUint192(pendingTimelock);
        emit TimelockProposalCanceled();
    }

    /// @notice Override transferOwnership to use timelock
    /// @param newOwner The new owner address
    function transferOwnership(address newOwner) public virtual override onlyOwner {
        require(pendingOwnershipChange.validAt == 0, PendingUpdate());
        require(newOwner != address(0), ZeroOwner());

        pendingOwnershipChange.update(newOwner, timelock);

        emit OwnershipTransferProposed(newOwner, pendingOwnershipChange.validAt);
    }

    /// @notice Override renounceOwnership to use timelock
    function renounceOwnership() public virtual override onlyOwner {
        require(pendingOwnershipChange.validAt == 0, PendingUpdate());

        pendingOwnershipChange.update(DEAD_ADDRESS, timelock);

        emit OwnershipRenounceProposed(pendingOwnershipChange.validAt);
    }

    /// @inheritdoc IManageableOracle
    function acceptOwnershipTransfer() external virtual onlyOwner afterTimelock(pendingOwnershipChange.validAt) {
        require(pendingOwnershipChange.value != DEAD_ADDRESS, InvalidOwnershipChangeType());

        address newOwner = pendingOwnershipChange.value;
        _resetPendingAddress(pendingOwnershipChange);

        transferOwnership(newOwner);
    }

    /// @inheritdoc IManageableOracle
    function acceptOwnershipRenounce() external virtual onlyOwner afterTimelock(pendingOwnershipChange.validAt) {
        require(pendingOwnershipChange.value == address(0xdead), InvalidOwnershipChangeType());

        _resetPendingAddress(pendingOwnershipChange);
        renounceOwnership();
    }

    /// @inheritdoc IManageableOracle
    function cancelOwnershipChange() external virtual onlyOwner {
        require(pendingOwnershipChange.validAt != 0, NoPendingUpdateToCancel());

        _resetPendingAddress(pendingOwnershipChange);
        emit OwnershipChangeCanceled();
    }

    /// @inheritdoc ISiloOracle
    function beforeQuote(address _baseToken) external virtual {
        oracle.beforeQuote(_baseToken);
    }

    /// @inheritdoc ISiloOracle
    function quote(uint256 _baseAmount, address _baseToken) external view virtual returns (uint256 quoteAmount) {
        quoteAmount = oracle.quote(_baseAmount, _baseToken);
    }

    /// @inheritdoc ISiloOracle
    function quoteToken() external view virtual returns (address token) {
        token = QUOTE_TOKEN;
    }

    function _resetPendingAddress(PendingAddress storage _pending) internal virtual {
        _pending.value = address(0);
        _pending.validAt = 0;
    }

    function _resetPendingUint192(PendingUint192 storage _pending) internal virtual {
        _pending.value = 0;
        _pending.validAt = 0;
    }
}
