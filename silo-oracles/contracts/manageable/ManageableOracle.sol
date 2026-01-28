// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Initializable} from "openzeppelin5-upgradeable/proxy/utils/Initializable.sol";

import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IManageableOracle} from "silo-oracles/contracts/interfaces/IManageableOracle.sol";
import {PendingAddress, PendingUint192, PendingLib} from "silo-vaults/contracts/libraries/PendingLib.sol";
import {IVersioned} from "silo-core/contracts/interfaces/IVersioned.sol";
import {TokenHelper} from "silo-core/contracts/lib/TokenHelper.sol";

/// @title ManageableOracle
/// @notice Oracle forwarder that allows updating the oracle address with time lock and owner approval
contract ManageableOracle is ISiloOracle, IManageableOracle, Initializable, IVersioned {
    using PendingLib for PendingAddress;
    using PendingLib for PendingUint192;

    address public constant DEAD_ADDRESS = address(0xdead);

    /// @dev Minimum time lock duration
    uint32 public constant MIN_TIMELOCK = 1 days;

    /// @dev Maximum time lock duration
    uint32 public constant MAX_TIMELOCK = 7 days;

    address public owner;

    /// @dev Quote token address (set during initialization)
    address public quoteToken;

    /// @dev Base token address (set during initialization)
    address public baseToken;

    /// @dev Base token decimals (set during initialization)
    uint256 public baseTokenDecimals;

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

    /// @dev Modifier to check if the caller is the owner
    modifier onlyOwner() {
        require(msg.sender == owner, OnlyOwner());
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the ManageableOracle with underlying oracle factory
    /// @param _underlyingOracleFactory Factory address to create the underlying oracle
    /// @param _underlyingOracleInitData Calldata to call the factory and create the underlying oracle
    /// @param _owner Address that will own the contract
    /// @param _timelock Initial time lock duration
    /// @param _baseToken Base token address for the oracle
    /// @dev This method is primarily used by SiloDeployer to create the oracle during deployment.
    ///      The oracle address is extracted from the factory call return data.
    function initialize(
        address _underlyingOracleFactory,
        bytes calldata _underlyingOracleInitData,
        address _owner,
        uint32 _timelock,
        address _baseToken
    ) external initializer {
        require(_underlyingOracleFactory != address(0), ZeroFactory());

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = _underlyingOracleFactory.call(_underlyingOracleInitData);
        require(success && data.length == 32, FailedToCreateAnOracle());

        address createdOracle = abi.decode(data, (address));
        __ManageableOracle_init(ISiloOracle(createdOracle), _owner, _timelock, _baseToken);
    }

    /// @notice Initialize the ManageableOracle
    /// @param _oracle Initial oracle address
    /// @param _owner Address that will own the contract
    /// @param _timelock Initial time lock duration
    /// @param _baseToken Base token address for the oracle
    function initialize(ISiloOracle _oracle, address _owner, uint32 _timelock, address _baseToken) external {
        __ManageableOracle_init(_oracle, _owner, _timelock, _baseToken);
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

    /// @dev The new owner accepts the ownership transfer.
    function acceptOwnership() external virtual afterTimelock(pendingOwnership.validAt) {
        require(pendingOwnership.value != DEAD_ADDRESS, InvalidOwnershipChangeType());
        require(pendingOwnership.value == msg.sender, OwnableUnauthorizedAccount());

        _resetPendingAddress(pendingOwnership);
        _transferOwnership(msg.sender);
    }

    /// @inheritdoc IManageableOracle
    function acceptRenounceOwnership() external virtual onlyOwner afterTimelock(pendingOwnership.validAt) {
        require(pendingOwnership.value == DEAD_ADDRESS, InvalidOwnershipChangeType());
        require(pendingOracle.validAt == 0, PendingOracleUpdate());

        _resetPendingAddress(pendingOwnership);
        _transferOwnership(address(0));
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

    /// @inheritdoc IManageableOracle
    function oracleVerification(ISiloOracle _oracle, address _baseToken) public view virtual {
        require(address(_oracle) != address(0), ZeroOracle());
        require(_oracle.quoteToken() == quoteToken, QuoteTokenMustBeTheSame());

        // sanity check
        uint256 price = _oracle.quote(10 ** baseTokenDecimals, _baseToken);
        require(price != 0, OracleQuoteFailed());
    }

    /// @notice Internal initialization function for ManageableOracle
    /// @param _oracle Initial oracle address
    /// @param _owner Address that will own the contract
    /// @param _timelock Initial time lock duration
    /// @param _baseToken Base token address for the oracle
    // solhint-disable-next-line func-name-mixedcase
    function __ManageableOracle_init(ISiloOracle _oracle, address _owner, uint32 _timelock, address _baseToken)
        internal
        virtual
        onlyInitializing
    {
        require(_baseToken != address(0), ZeroBaseToken());
        require(_owner != address(0), ZeroOwner());
        require(_timelock >= MIN_TIMELOCK && _timelock <= MAX_TIMELOCK, InvalidTimelock());

        quoteToken = _oracle.quoteToken();
        baseToken = _baseToken;
        baseTokenDecimals = TokenHelper.assertAndGetDecimals(_baseToken);
        require(baseTokenDecimals != 0, BaseTokenDecimalsMustBeGreaterThanZero());

        oracle = _oracle;
        timelock = _timelock;

        oracleVerification(_oracle, _baseToken);

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

    function _transferOwnership(address _newOwner) internal virtual {
        address oldOwner = owner;
        owner = _newOwner;
        emit OwnershipTransferred(oldOwner, _newOwner);
    }
}
