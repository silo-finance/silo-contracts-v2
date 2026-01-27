// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Initializable} from "openzeppelin5-upgradeable/proxy/utils/Initializable.sol";

import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IManageableOracle} from "silo-oracles/contracts/interfaces/IManageableOracle.sol";
import {PendingAddress, PendingUint192, PendingLib} from "silo-vaults/contracts/libraries/PendingLib.sol";
import {Ownable1and2Steps} from "common/access/Ownable1and2Steps.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {IVersioned} from "silo-core/contracts/interfaces/IVersioned.sol";

/// @title ManageableOracle
/// @notice Oracle forwarder that allows updating the oracle address with time lock and owner approval
contract ManageableOracle is ISiloOracle, IManageableOracle, Ownable1and2Steps, Initializable, IVersioned {
    using PendingLib for PendingAddress;
    using PendingLib for PendingUint192;

    address public constant DEAD_ADDRESS = address(0xdead);

    /// @dev Minimum time lock duration
    uint32 public constant MIN_TIMELOCK = 1 days;

    /// @dev Maximum time lock duration
    uint32 public constant MAX_TIMELOCK = 7 days;

    /// @dev Quote token address (set during initialization)
    address public quoteToken;

    /// @dev Current oracle
    ISiloOracle public oracle;

    /// @dev Current time lock duration
    uint32 public timelock;

    /// @dev Pending oracle address
    PendingAddress public pendingOracle;

    /// @dev Pending time lock duration
    PendingUint192 public pendingTimelock;

    /// @dev Pending ownership change (DEAD_ADDRESS means renounce, otherwise transfer)
    /// @notice Only one type of ownership change can be pending at a time (either transfer or renounce)
    PendingAddress public pendingOwnership;

    /// @dev Modifier to check if timelock has elapsed
    modifier afterTimelock(uint64 _validAt) {
        require(_validAt != 0, NoPendingUpdate());
        require(block.timestamp >= _validAt, TimelockNotExpired());
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() Ownable1and2Steps(DEAD_ADDRESS) {
        // lock the implementation
        _transferOwnership(address(0));
        _disableInitializers();
    }

    /// @notice Initialize the ManageableOracle with underlying oracle factory
    /// @param _underlyingOracleFactory Factory address to create the underlying oracle
    /// @param _underlyingOracleInitData Calldata to call the factory and create the underlying oracle
    /// @param _owner Address that will own the contract
    /// @param _timelock Initial time lock duration
    /// @dev This method is primarily used by SiloDeployer to create the oracle during deployment.
    ///      The oracle address is extracted from the factory call return data.
    function initialize(
        address _underlyingOracleFactory,
        bytes calldata _underlyingOracleInitData,
        address _owner,
        uint32 _timelock
    ) external initializer {
        require(_underlyingOracleFactory != address(0), ZeroFactory());

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = _underlyingOracleFactory.call(_underlyingOracleInitData);
        require(success && data.length == 32, FailedToCreateAnOracle());

        address createdOracle = abi.decode(data, (address));
        __ManageableOracle_init(ISiloOracle(createdOracle), _owner, _timelock);
    }

    /// @notice Initialize the ManageableOracle
    /// @param _oracle Initial oracle address
    /// @param _owner Address that will own the contract
    /// @param _timelock Initial time lock duration
    function initialize(ISiloOracle _oracle, address _owner, uint32 _timelock) external {
        __ManageableOracle_init(_oracle, _owner, _timelock);
    }

    /// @inheritdoc IManageableOracle
    function proposeOracle(ISiloOracle _oracle) external virtual onlyOwner {
        require(pendingOracle.validAt == 0, PendingUpdate());
        require(address(_oracle) != address(0), ZeroOracle());
        require(_oracle.quoteToken() == quoteToken, QuoteTokenMustBeTheSame());
        // base token should be the same as well, but we don't have easy way to check it

        pendingOracle.update(address(_oracle), timelock);

        emit OracleProposed(_oracle, pendingOracle.validAt);
    }

    /// @inheritdoc IManageableOracle
    function proposeTimelock(uint32 _timelock) external virtual onlyOwner {
        require(pendingTimelock.validAt == 0, PendingUpdate());
        require(_timelock >= MIN_TIMELOCK && _timelock <= MAX_TIMELOCK, InvalidTimelock());

        pendingTimelock.update(uint184(_timelock), timelock);

        emit TimelockProposed(_timelock, pendingTimelock.validAt);
    }

    /// @inheritdoc IManageableOracle
    function proposeTransferOwnership(address _newOwner) external virtual onlyOwner {
        require(pendingOwnership.validAt == 0, PendingUpdate());
        require(_newOwner != address(0), ZeroOwner());
        require(_newOwner != DEAD_ADDRESS, UseRenounceOwnership());

        pendingOwnership.update(_newOwner, timelock);

        emit OwnershipTransferProposed(_newOwner, pendingOwnership.validAt);
    }

    /// @inheritdoc IManageableOracle
    function proposeRenounceOwnership() external virtual onlyOwner {
        require(pendingOwnership.validAt == 0, PendingUpdate());

        pendingOwnership.update(DEAD_ADDRESS, timelock);

        emit OwnershipRenounceProposed(pendingOwnership.validAt);
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

    /// @inheritdoc IManageableOracle
    function cancelTransferOwnership() external virtual onlyOwner {
        require(pendingOwnership.validAt != 0, NoPendingUpdateToCancel());
        require(pendingOwnership.value != DEAD_ADDRESS, InvalidOwnershipChangeType());

        _resetPendingAddress(pendingOwnership);
        emit OwnershipTransferCanceled();
    }

    /// @inheritdoc IManageableOracle
    function cancelRenounceOwnership() external virtual onlyOwner {
        require(pendingOwnership.validAt != 0, NoPendingUpdateToCancel());
        require(pendingOwnership.value == DEAD_ADDRESS, InvalidOwnershipChangeType());

        _resetPendingAddress(pendingOwnership);
        emit OwnershipRenounceCanceled();
    }

    /// @inheritdoc ISiloOracle
    function beforeQuote(address _baseToken) external virtual {
        oracle.beforeQuote(_baseToken);
    }

    /// @inheritdoc ISiloOracle
    function quote(uint256 _baseAmount, address _baseToken) external view virtual returns (uint256 quoteAmount) {
        quoteAmount = oracle.quote(_baseAmount, _baseToken);
    }

    /// @inheritdoc IVersioned
    // solhint-disable-next-line func-name-mixedcase
    function VERSION() external pure override returns (string memory version) {
        version = "ManageableOracle v1.0.0";
    }

    /// @inheritdoc Ownable2Step
    /// @notice This function has been overridden and implemented with timelock protection.
    function transferOwnership(address newOwner)
        public
        virtual
        override
        onlyOwner
        afterTimelock(pendingOwnership.validAt)
    {
        require(pendingOwnership.value != DEAD_ADDRESS, InvalidOwnershipChangeType());
        require(pendingOwnership.value == newOwner, InvalidOwnershipChangeType());

        _resetPendingAddress(pendingOwnership);

        _transferOwnership(newOwner);
    }

    /// @inheritdoc Ownable
    /// @notice This function has been overridden and implemented with timelock protection.
    function renounceOwnership() public virtual override onlyOwner afterTimelock(pendingOwnership.validAt) {
        require(pendingOwnership.value == DEAD_ADDRESS, InvalidOwnershipChangeType());
        require(pendingOracle.validAt == 0, PendingOracleUpdate());

        _resetPendingAddress(pendingOwnership);
        _transferOwnership(address(0));
    }

    // solhint-disable-next-line func-name-mixedcase
    function __ManageableOracle_init(ISiloOracle _oracle, address _owner, uint32 _timelock)
        internal
        virtual
        onlyInitializing
    {
        require(address(_oracle) != address(0), ZeroOracle());
        require(_owner != address(0), ZeroOwner());
        require(_timelock >= MIN_TIMELOCK && _timelock <= MAX_TIMELOCK, InvalidTimelock());

        quoteToken = _oracle.quoteToken();
        oracle = _oracle;
        timelock = _timelock;

        _transferOwnership(_owner);

        emit OracleUpdated(_oracle);
        emit TimelockUpdated(_timelock);
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
