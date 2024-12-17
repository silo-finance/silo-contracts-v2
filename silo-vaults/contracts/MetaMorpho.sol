// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";
import {ERC4626, Math} from "openzeppelin5/token/ERC20/extensions/ERC4626.sol";
import {IERC4626, IERC20, IERC20Metadata} from "openzeppelin5/interfaces/IERC4626.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {ERC20Permit} from "openzeppelin5/token/ERC20/extensions/ERC20Permit.sol";
import {Multicall} from "openzeppelin5/utils/Multicall.sol";
import {ERC20} from "openzeppelin5/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {UtilsLib} from "morpho-blue/libraries/UtilsLib.sol";

import {
    MarketConfig,
    PendingUint192,
    PendingAddress,
    MarketAllocation,
    IMetaMorphoBase,
    IMetaMorphoStaticTyping
} from "./interfaces/IMetaMorpho.sol";

import {INotificationReceiver} from "./interfaces/INotificationReceiver.sol";
import {IVaultIncentivesModule} from "./interfaces/IVaultIncentivesModule.sol";
import {IIncentivesClaimingLogic} from "./interfaces/IIncentivesClaimingLogic.sol";

import {PendingUint192, PendingAddress, PendingLib} from "./libraries/PendingLib.sol";
import {ConstantsLib} from "./libraries/ConstantsLib.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";

/// @title MetaMorpho
/// @author Forked with gratitude from Morpho Labs.
/// @custom:contact security@morpho.org
/// @notice ERC4626 compliant vault allowing users to deposit assets to Morpho.
contract MetaMorpho is ERC4626, ERC20Permit, Ownable2Step, Multicall, IMetaMorphoStaticTyping {
    uint256 constant WAD = 1e18;

    using Math for uint256;
    using SafeERC20 for IERC20;
    using PendingLib for PendingUint192;
    using PendingLib for PendingAddress;

    /* IMMUTABLES */
    
    /// @notice OpenZeppelin decimals offset used by the ERC4626 implementation.
    /// @dev Calculated to be max(0, 18 - underlyingDecimals) at construction, so the initial conversion rate maximizes
    /// precision between shares and assets.
    uint8 public immutable DECIMALS_OFFSET;

    IVaultIncentivesModule public immutable INCENTIVES_MODULE;

    /* STORAGE */

    /// @inheritdoc IMetaMorphoBase
    address public curator;

    /// @inheritdoc IMetaMorphoBase
    mapping(address => bool) public isAllocator;

    /// @inheritdoc IMetaMorphoBase
    address public guardian;

    /// @inheritdoc IMetaMorphoStaticTyping
    mapping(IERC4626 => MarketConfig) public config;

    /// @inheritdoc IMetaMorphoBase
    uint256 public timelock;

    /// @inheritdoc IMetaMorphoStaticTyping
    PendingAddress public pendingGuardian;

    /// @inheritdoc IMetaMorphoStaticTyping
    mapping(IERC4626 => PendingUint192) public pendingCap;

    /// @inheritdoc IMetaMorphoStaticTyping
    PendingUint192 public pendingTimelock;

    /// @inheritdoc IMetaMorphoBase
    uint96 public fee;

    /// @inheritdoc IMetaMorphoBase
    address public feeRecipient;

    /// @inheritdoc IMetaMorphoBase
    address public skimRecipient;

    /// @inheritdoc IMetaMorphoBase
    IERC4626[] public supplyQueue;

    /// @inheritdoc IMetaMorphoBase
    IERC4626[] public withdrawQueue;

    /// @inheritdoc IMetaMorphoBase
    uint256 public lastTotalAssets;

    bool transient _lock;

    /* CONSTRUCTOR */

    /// @dev Initializes the contract.
    /// @param _owner The owner of the contract.
    /// @param _initialTimelock The initial timelock.
    /// @param _vaultIncentivesModule The vault incentives module.
    /// @param _asset The address of the underlying asset.
    /// @param _name The name of the vault.
    /// @param _symbol The symbol of the vault.
    constructor(
        address _owner,
        uint256 _initialTimelock,
        IVaultIncentivesModule _vaultIncentivesModule,
        address _asset,
        string memory _name,
        string memory _symbol
    ) ERC4626(IERC20(_asset)) ERC20Permit(_name) ERC20(_name, _symbol) Ownable(_owner) {
        require(_asset != address(0), ErrorsLib.ZeroAddress());
        require(address(_vaultIncentivesModule) != address(0), ErrorsLib.ZeroAddress());

        DECIMALS_OFFSET = uint8(UtilsLib.zeroFloorSub(18, IERC20Metadata(_asset).decimals()));

        _checkTimelockBounds(_initialTimelock);
        _setTimelock(_initialTimelock);
        INCENTIVES_MODULE = _vaultIncentivesModule;
    }

    /* MODIFIERS */

    /// @dev Reverts if the caller doesn't have the curator role.
    modifier onlyCuratorRole() {
        address sender = _msgSender();
        if (sender != curator && sender != owner()) revert ErrorsLib.NotCuratorRole();

        _;
    }

    /// @dev Reverts if the caller doesn't have the allocator role.
    modifier onlyAllocatorRole() {
        address sender = _msgSender();
        if (!isAllocator[sender] && sender != curator && sender != owner()) {
            revert ErrorsLib.NotAllocatorRole();
        }

        _;
    }

    /// @dev Reverts if the caller doesn't have the guardian role.
    modifier onlyGuardianRole() {
        if (_msgSender() != owner() && _msgSender() != guardian) revert ErrorsLib.NotGuardianRole();

        _;
    }

    /// @dev Reverts if the caller doesn't have the curator nor the guardian role.
    modifier onlyCuratorOrGuardianRole() {
        if (_msgSender() != guardian && _msgSender() != curator && _msgSender() != owner()) {
            revert ErrorsLib.NotCuratorNorGuardianRole();
        }

        _;
    }

    /// @dev Makes sure conditions are met to accept a pending value.
    /// @dev Reverts if:
    /// - there's no pending value;
    /// - the timelock has not elapsed since the pending value has been submitted.
    modifier afterTimelock(uint256 _validAt) {
        if (_validAt == 0) revert ErrorsLib.NoPendingValue();
        if (block.timestamp < _validAt) revert ErrorsLib.TimelockNotElapsed();

        _;
    }

    /* ONLY OWNER FUNCTIONS */

    /// @inheritdoc IMetaMorphoBase
    function setCurator(address _newCurator) external virtual onlyOwner {
        if (_newCurator == curator) revert ErrorsLib.AlreadySet();

        curator = _newCurator;

        emit EventsLib.SetCurator(_newCurator);
    }

    /// @inheritdoc IMetaMorphoBase
    function setIsAllocator(address _newAllocator, bool _newIsAllocator) external virtual onlyOwner {
        if (isAllocator[_newAllocator] == _newIsAllocator) revert ErrorsLib.AlreadySet();

        isAllocator[_newAllocator] = _newIsAllocator;

        emit EventsLib.SetIsAllocator(_newAllocator, _newIsAllocator);
    }

    /// @inheritdoc IMetaMorphoBase
    function setSkimRecipient(address _newSkimRecipient) external virtual onlyOwner {
        if (_newSkimRecipient == skimRecipient) revert ErrorsLib.AlreadySet();

        skimRecipient = _newSkimRecipient;

        emit EventsLib.SetSkimRecipient(_newSkimRecipient);
    }

    /// @inheritdoc IMetaMorphoBase
    function submitTimelock(uint256 _newTimelock) external virtual onlyOwner {
        if (_newTimelock == timelock) revert ErrorsLib.AlreadySet();
        if (pendingTimelock.validAt != 0) revert ErrorsLib.AlreadyPending();
        _checkTimelockBounds(_newTimelock);

        if (_newTimelock > timelock) {
            _setTimelock(_newTimelock);
        } else {
            // Safe "unchecked" cast because newTimelock <= MAX_TIMELOCK.
            pendingTimelock.update(uint184(_newTimelock), timelock);

            emit EventsLib.SubmitTimelock(_newTimelock);
        }
    }

    /// @inheritdoc IMetaMorphoBase
    function setFee(uint256 _newFee) external virtual onlyOwner {
        if (_newFee == fee) revert ErrorsLib.AlreadySet();
        if (_newFee > ConstantsLib.MAX_FEE) revert ErrorsLib.MaxFeeExceeded();
        if (_newFee != 0 && feeRecipient == address(0)) revert ErrorsLib.ZeroFeeRecipient();

        // Accrue fee using the previous fee set before changing it.
        _updateLastTotalAssets(_accrueFee());

        // Safe "unchecked" cast because newFee <= MAX_FEE.
        fee = uint96(_newFee);

        emit EventsLib.SetFee(_msgSender(), fee);
    }

    /// @inheritdoc IMetaMorphoBase
    function setFeeRecipient(address _newFeeRecipient) external virtual onlyOwner {
        if (_newFeeRecipient == feeRecipient) revert ErrorsLib.AlreadySet();
        if (_newFeeRecipient == address(0) && fee != 0) revert ErrorsLib.ZeroFeeRecipient();

        // Accrue fee to the previous fee recipient set before changing it.
        _updateLastTotalAssets(_accrueFee());

        feeRecipient = _newFeeRecipient;

        emit EventsLib.SetFeeRecipient(_newFeeRecipient);
    }

    /// @inheritdoc IMetaMorphoBase
    function submitGuardian(address _newGuardian) external virtual onlyOwner {
        if (_newGuardian == guardian) revert ErrorsLib.AlreadySet();
        if (pendingGuardian.validAt != 0) revert ErrorsLib.AlreadyPending();

        if (guardian == address(0)) {
            _setGuardian(_newGuardian);
        } else {
            pendingGuardian.update(_newGuardian, timelock);

            emit EventsLib.SubmitGuardian(_newGuardian);
        }
    }

    /* ONLY CURATOR FUNCTIONS */

    /// @inheritdoc IMetaMorphoBase
    function submitCap(IERC4626 _market, uint256 _newSupplyCap) external virtual onlyCuratorRole {
        if (_market.asset() != asset()) revert ErrorsLib.InconsistentAsset(_market);
        if (pendingCap[_market].validAt != 0) revert ErrorsLib.AlreadyPending();
        if (config[_market].removableAt != 0) revert ErrorsLib.PendingRemoval();
        uint256 supplyCap = config[_market].cap;
        if (_newSupplyCap == supplyCap) revert ErrorsLib.AlreadySet();

        if (_newSupplyCap < supplyCap) {
            _setCap(_market, SafeCast.toUint184(_newSupplyCap));
        } else {
            pendingCap[_market].update(SafeCast.toUint184(_newSupplyCap), timelock);

            emit EventsLib.SubmitCap(_msgSender(), _market, _newSupplyCap);
        }
    }

    /// @inheritdoc IMetaMorphoBase
    function submitMarketRemoval(IERC4626 _market) external virtual onlyCuratorRole {
        if (config[_market].removableAt != 0) revert ErrorsLib.AlreadyPending();
        if (config[_market].cap != 0) revert ErrorsLib.NonZeroCap();
        if (!config[_market].enabled) revert ErrorsLib.MarketNotEnabled(_market);
        if (pendingCap[_market].validAt != 0) revert ErrorsLib.PendingCap(_market);

        // Safe "unchecked" cast because timelock <= MAX_TIMELOCK.
        config[_market].removableAt = uint64(block.timestamp + timelock);

        emit EventsLib.SubmitMarketRemoval(_msgSender(), _market);
    }

    /* ONLY ALLOCATOR FUNCTIONS */

    /// @inheritdoc IMetaMorphoBase
    function setSupplyQueue(IERC4626[] calldata _newSupplyQueue) external virtual onlyAllocatorRole {
        uint256 length = _newSupplyQueue.length;

        if (length > ConstantsLib.MAX_QUEUE_LENGTH) revert ErrorsLib.MaxQueueLengthExceeded();

        for (uint256 i; i < length; ++i) {
            IERC4626 market = _newSupplyQueue[i];
            if (config[market].cap == 0) revert ErrorsLib.UnauthorizedMarket(market);
        }

        supplyQueue = _newSupplyQueue;

        emit EventsLib.SetSupplyQueue(_msgSender(), _newSupplyQueue);
    }

    /// @inheritdoc IMetaMorphoBase
    function updateWithdrawQueue(uint256[] calldata _indexes) external virtual onlyAllocatorRole {
        uint256 newLength = _indexes.length;
        uint256 currLength = withdrawQueue.length;

        bool[] memory seen = new bool[](currLength);
        IERC4626[] memory newWithdrawQueue = new IERC4626[](newLength);

        for (uint256 i; i < newLength; ++i) {
            uint256 prevIndex = _indexes[i];

            // If prevIndex >= currLength, it will revert with native "Index out of bounds".
            IERC4626 market = withdrawQueue[prevIndex];
            if (seen[prevIndex]) revert ErrorsLib.DuplicateMarket(market);
            seen[prevIndex] = true;

            newWithdrawQueue[i] = market;
        }

        for (uint256 i; i < currLength; ++i) {
            if (!seen[i]) {
                IERC4626 market = withdrawQueue[i];

                if (config[market].cap != 0) revert ErrorsLib.InvalidMarketRemovalNonZeroCap(market);
                if (pendingCap[market].validAt != 0) revert ErrorsLib.PendingCap(market);

                if (market.balanceOf(address(this)) != 0) {
                    if (config[market].removableAt == 0) revert ErrorsLib.InvalidMarketRemovalNonZeroSupply(market);

                    if (block.timestamp < config[market].removableAt) {
                        revert ErrorsLib.InvalidMarketRemovalTimelockNotElapsed(market);
                    }
                }

                delete config[market];
            }
        }

        withdrawQueue = newWithdrawQueue;

        emit EventsLib.SetWithdrawQueue(_msgSender(), newWithdrawQueue);
    }

    /// @inheritdoc IMetaMorphoBase
    function reallocate(MarketAllocation[] calldata _allocations) external virtual onlyAllocatorRole {
        uint256 totalSupplied;
        uint256 totalWithdrawn;
        for (uint256 i; i < _allocations.length; ++i) {
            MarketAllocation memory allocation = _allocations[i];

            // in original MetaMorpho, we are not checking liquidity, so this realocation will fail if not enough assets
            (uint256 supplyAssets, uint256 supplyShares) = _supplyBalance(allocation.market);
            uint256 withdrawn = UtilsLib.zeroFloorSub(supplyAssets, allocation.assets);

            if (withdrawn > 0) {
                if (!config[allocation.market].enabled) revert ErrorsLib.MarketNotEnabled(allocation.market);

                // Guarantees that unknown frontrunning donations can be withdrawn, in order to disable a market.
                uint256 shares;
                if (allocation.assets == 0) {
                    shares = supplyShares;
                    withdrawn = 0;
                }

                uint256 withdrawnAssets;
                uint256 withdrawnShares;

                if (shares != 0) {
                    withdrawnAssets = allocation.market.redeem(shares, address(this), address(this));
                    withdrawnShares = shares;
                } else {
                    withdrawnAssets = withdrawn;
                    withdrawnShares = allocation.market.withdraw(withdrawn, address(this), address(this));
                }

                emit EventsLib.ReallocateWithdraw(_msgSender(), allocation.market, withdrawnAssets, withdrawnShares);

                totalWithdrawn += withdrawnAssets;
            } else {
                uint256 suppliedAssets = allocation.assets == type(uint256).max
                    ? UtilsLib.zeroFloorSub(totalWithdrawn, totalSupplied)
                    : UtilsLib.zeroFloorSub(allocation.assets, supplyAssets);

                if (suppliedAssets == 0) continue;

                uint256 supplyCap = config[allocation.market].cap;
                if (supplyCap == 0) revert ErrorsLib.UnauthorizedMarket(allocation.market);

                if (supplyAssets + suppliedAssets > supplyCap) revert ErrorsLib.SupplyCapExceeded(allocation.market);

                // The market's loan asset is guaranteed to be the vault's asset because it has a non-zero supply cap.
                uint256 suppliedShares = allocation.market.deposit(suppliedAssets, address(this));

                emit EventsLib.ReallocateSupply(_msgSender(), allocation.market, suppliedAssets, suppliedShares);

                totalSupplied += suppliedAssets;
            }
        }

        if (totalWithdrawn != totalSupplied) revert ErrorsLib.InconsistentReallocation();
    }

    /* REVOKE FUNCTIONS */

    /// @inheritdoc IMetaMorphoBase
    function revokePendingTimelock() external virtual onlyGuardianRole {
        delete pendingTimelock;

        emit EventsLib.RevokePendingTimelock(_msgSender());
    }

    /// @inheritdoc IMetaMorphoBase
    function revokePendingGuardian() external virtual onlyGuardianRole {
        delete pendingGuardian;

        emit EventsLib.RevokePendingGuardian(_msgSender());
    }

    /// @inheritdoc IMetaMorphoBase
    function revokePendingCap(IERC4626 _market) external virtual onlyCuratorOrGuardianRole {
        delete pendingCap[_market];

        emit EventsLib.RevokePendingCap(_msgSender(), _market);
    }

    /// @inheritdoc IMetaMorphoBase
    function revokePendingMarketRemoval(IERC4626 _market) external virtual onlyCuratorOrGuardianRole {
        delete config[_market].removableAt;

        emit EventsLib.RevokePendingMarketRemoval(_msgSender(), _market);
    }

    /* EXTERNAL */

    /// @inheritdoc IMetaMorphoBase
    function supplyQueueLength() external view virtual returns (uint256) {
        return supplyQueue.length;
    }

    /// @inheritdoc IMetaMorphoBase
    function withdrawQueueLength() external view virtual returns (uint256) {
        return withdrawQueue.length;
    }

    /// @inheritdoc IMetaMorphoBase
    function acceptTimelock() external virtual afterTimelock(pendingTimelock.validAt) {
        _setTimelock(pendingTimelock.value);
    }

    /// @inheritdoc IMetaMorphoBase
    function acceptGuardian() external virtual afterTimelock(pendingGuardian.validAt) {
        _setGuardian(pendingGuardian.value);
    }

    /// @inheritdoc IMetaMorphoBase
    function acceptCap(IERC4626 _market)
        external
        virtual
        afterTimelock(pendingCap[_market].validAt)
    {
        // Safe "unchecked" cast because pendingCap <= type(uint184).max.
        _setCap(_market, uint184(pendingCap[_market].value));
    }

    /// @inheritdoc IMetaMorphoBase
    function skim(address _token) external virtual {
        if (skimRecipient == address(0)) revert ErrorsLib.ZeroAddress();

        uint256 amount = IERC20(_token).balanceOf(address(this));

        IERC20(_token).safeTransfer(skimRecipient, amount);

        emit EventsLib.Skim(_msgSender(), _token, amount);
    }

    function claimRewards() public {
        // TODO we can use supplyQueue as markets inputs, but what if we change queue and we still have rewards?
        // I think it is better to let INCENTIVES_MODULE decide about markets
        // (address[] memory logics) = INCENTIVES_MODULE.getMarketsIncentivesClaimingLogics(supplyQueue);
        (address[] memory logics) = INCENTIVES_MODULE.getAllIncentivesClaimingLogics();

        require(!_lock, ErrorsLib.ClaimingRewardsError());
        _lock = true;

        for (uint256 i; i < logics.length; i++) {
            logics[i].delegatecall(abi.encodeWithSelector(IIncentivesClaimingLogic.claimRewardsAndDistribute.selector));
            // result of call is ignored
        }

        _lock = false;
    }

    /* ERC4626 (PUBLIC) */

    /// @inheritdoc IERC20Metadata
    function decimals() public view virtual override(ERC20, ERC4626) returns (uint8) {
        return ERC4626.decimals();
    }

    /// @inheritdoc IERC4626
    /// @dev Warning: May be higher than the actual max deposit due to duplicate markets in the supplyQueue.
    function maxDeposit(address) public view virtual override returns (uint256) {
        return _maxDeposit();
    }

    /// @inheritdoc IERC4626
    /// @dev Warning: May be higher than the actual max mint due to duplicate markets in the supplyQueue.
    function maxMint(address) public view virtual override returns (uint256) {
        uint256 suppliable = _maxDeposit();

        return _convertToShares(suppliable, Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    /// @dev Warning: May be lower than the actual amount of assets that can be withdrawn by `owner` due to conversion
    /// roundings between shares and assets.
    function maxWithdraw(address _owner) public view virtual override returns (uint256 assets) {
        (assets,,) = _maxWithdraw(_owner);
    }

    /// @inheritdoc IERC4626
    /// @dev Warning: May be lower than the actual amount of shares that can be redeemed by `owner` due to conversion
    /// roundings between shares and assets.
    function maxRedeem(address _owner) public view virtual override returns (uint256) {
        (uint256 assets, uint256 newTotalSupply, uint256 newTotalAssets) = _maxWithdraw(_owner);

        return _convertToSharesWithTotals(assets, newTotalSupply, newTotalAssets, Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 _assets, address _receiver) public virtual override returns (uint256 shares) {
        uint256 newTotalAssets = _accrueFee();

        // Update `lastTotalAssets` to avoid an inconsistent state in a re-entrant context.
        // It is updated again in `_deposit`.
        lastTotalAssets = newTotalAssets;

        shares = _convertToSharesWithTotals(_assets, totalSupply(), newTotalAssets, Math.Rounding.Floor);

        _deposit(_msgSender(), _receiver, _assets, shares);
    }

    /// @inheritdoc IERC4626
    function mint(uint256 _shares, address _receiver) public virtual override returns (uint256 assets) {
        uint256 newTotalAssets = _accrueFee();

        // Update `lastTotalAssets` to avoid an inconsistent state in a re-entrant context.
        // It is updated again in `_deposit`.
        lastTotalAssets = newTotalAssets;

        assets = _convertToAssetsWithTotals(_shares, totalSupply(), newTotalAssets, Math.Rounding.Ceil);

        _deposit(_msgSender(), _receiver, assets, _shares);
    }

    /// @inheritdoc IERC4626
    function withdraw(uint256 _assets, address _receiver, address _owner)
        public
        virtual
        override
        returns (uint256 shares)
    {
        uint256 newTotalAssets = _accrueFee();

        // Do not call expensive `maxWithdraw` and optimistically withdraw assets.

        shares = _convertToSharesWithTotals(_assets, totalSupply(), newTotalAssets, Math.Rounding.Ceil);

        // `newTotalAssets - assets` may be a little off from `totalAssets()`.
        _updateLastTotalAssets(UtilsLib.zeroFloorSub(newTotalAssets, _assets));

        _withdraw(_msgSender(), _receiver, _owner, _assets, shares);
    }

    /// @inheritdoc IERC4626
    function redeem(
        uint256 _shares,
        address _receiver,
        address _owner
    ) public virtual override returns (uint256 assets) {
        uint256 newTotalAssets = _accrueFee();

        // Do not call expensive `maxRedeem` and optimistically redeem shares.

        assets = _convertToAssetsWithTotals(_shares, totalSupply(), newTotalAssets, Math.Rounding.Floor);

        // `newTotalAssets - assets` may be a little off from `totalAssets()`.
        _updateLastTotalAssets(UtilsLib.zeroFloorSub(newTotalAssets, assets));

        _withdraw(_msgSender(), _receiver, _owner, assets, _shares);
    }

    /// @inheritdoc IERC4626
    function totalAssets() public view virtual override returns (uint256 assets) {
        for (uint256 i; i < withdrawQueue.length; ++i) {
            IERC4626 market = withdrawQueue[i];
            assets += _expectedSupplyAssets(market, address(this));
        }
    }

    /* ERC4626 (INTERNAL) */

    /// @inheritdoc ERC4626
    function _decimalsOffset() internal view virtual override returns (uint8) {
        return DECIMALS_OFFSET;
    }

    /// @dev Returns the maximum amount of asset (`assets`) that the `owner` can withdraw from the vault, as well as the
    /// new vault's total supply (`newTotalSupply`) and total assets (`newTotalAssets`).
    function _maxWithdraw(address _owner)
        internal
        view
        virtual
        returns (uint256 assets, uint256 newTotalSupply, uint256 newTotalAssets)
    {
        uint256 feeShares;
        (feeShares, newTotalAssets) = _accruedFeeShares();
        newTotalSupply = totalSupply() + feeShares;

        assets = _convertToAssetsWithTotals(balanceOf(_owner), newTotalSupply, newTotalAssets, Math.Rounding.Floor);
        assets -= _simulateWithdrawMorpho(assets);
    }

    /// @dev Returns the maximum amount of assets that the vault can supply on Morpho.
    function _maxDeposit() internal view virtual returns (uint256 totalSuppliable) {
        for (uint256 i; i < supplyQueue.length; ++i) {
            IERC4626 market = supplyQueue[i];

            uint256 supplyCap = config[market].cap;
            if (supplyCap == 0) continue;

            totalSuppliable += UtilsLib.zeroFloorSub(supplyCap, market.maxDeposit(address(this)));
        }
    }

    /// @inheritdoc ERC4626
    /// @dev The accrual of performance fees is taken into account in the conversion.
    function _convertToShares(uint256 _assets, Math.Rounding _rounding) internal view virtual override returns (uint256) {
        (uint256 feeShares, uint256 newTotalAssets) = _accruedFeeShares();

        return _convertToSharesWithTotals(_assets, totalSupply() + feeShares, newTotalAssets, _rounding);
    }

    /// @inheritdoc ERC4626
    /// @dev The accrual of performance fees is taken into account in the conversion.
    function _convertToAssets(uint256 _shares, Math.Rounding _rounding) internal view virtual override returns (uint256) {
        (uint256 feeShares, uint256 newTotalAssets) = _accruedFeeShares();

        return _convertToAssetsWithTotals(_shares, totalSupply() + feeShares, newTotalAssets, _rounding);
    }

    /// @dev Returns the amount of shares that the vault would exchange for the amount of `assets` provided.
    /// @dev It assumes that the arguments `newTotalSupply` and `newTotalAssets` are up to date.
    function _convertToSharesWithTotals(
        uint256 _assets,
        uint256 _newTotalSupply,
        uint256 _newTotalAssets,
        Math.Rounding _rounding
    ) internal view virtual returns (uint256) {
        return _assets.mulDiv(_newTotalSupply + 10 ** _decimalsOffset(), _newTotalAssets + 1, _rounding);
    }

    /// @dev Returns the amount of assets that the vault would exchange for the amount of `shares` provided.
    /// @dev It assumes that the arguments `newTotalSupply` and `newTotalAssets` are up to date.
    function _convertToAssetsWithTotals(
        uint256 _shares,
        uint256 _newTotalSupply,
        uint256 _newTotalAssets,
        Math.Rounding _rounding
    ) internal view virtual returns (uint256) {
        return _shares.mulDiv(_newTotalAssets + 1, _newTotalSupply + 10 ** _decimalsOffset(), _rounding);
    }

    /// @inheritdoc ERC4626
    /// @dev Used in mint or deposit to deposit the underlying asset to Morpho markets.
    function _deposit(address _caller, address _receiver, uint256 _assets, uint256 _shares) internal virtual override {
        super._deposit(_caller, _receiver, _assets, _shares);

        _supplyMorpho(_assets);

        // `lastTotalAssets + assets` may be a little off from `totalAssets()`.
        _updateLastTotalAssets(lastTotalAssets + _assets);
    }

    /// @inheritdoc ERC4626
    /// @dev Used in redeem or withdraw to withdraw the underlying asset from Morpho markets.
    /// @dev Depending on 3 cases, reverts when withdrawing "too much" with:
    /// 1. NotEnoughLiquidity when withdrawing more than available liquidity.
    /// 2. ERC20InsufficientAllowance when withdrawing more than `caller`'s allowance.
    /// 3. ERC20InsufficientBalance when withdrawing more than `owner`'s balance.
    function _withdraw(address _caller, address _receiver, address _owner, uint256 _assets, uint256 _shares)
        internal
        virtual
        override
    {
        _withdrawMorpho(_assets);

        super._withdraw(_caller, _receiver, _owner, _assets, _shares);
    }

    /* INTERNAL */


    /// @dev Returns the vault's assets & corresponding shares supplied on the
    /// market defined by `market`, as well as the market's state.
    function _supplyBalance(IERC4626 _market)
        internal
        view
        virtual
        returns (uint256 assets, uint256 shares)
    {
        shares = _market.balanceOf(address(this));
        // we assume here, that in case of any interest on IERC4626, convertToAssets returns assets with interest
        assets = _market.convertToAssets(shares);
    }

    /// @dev Reverts if `newTimelock` is not within the bounds.
    function _checkTimelockBounds(uint256 _newTimelock) internal pure virtual {
        if (_newTimelock > ConstantsLib.MAX_TIMELOCK) revert ErrorsLib.AboveMaxTimelock();
        if (_newTimelock < ConstantsLib.MIN_TIMELOCK) revert ErrorsLib.BelowMinTimelock();
    }

    /// @dev Sets `timelock` to `newTimelock`.
    function _setTimelock(uint256 _newTimelock) internal virtual {
        timelock = _newTimelock;

        emit EventsLib.SetTimelock(_msgSender(), _newTimelock);

        delete pendingTimelock;
    }

    /// @dev Sets `guardian` to `newGuardian`.
    function _setGuardian(address _newGuardian) internal virtual {
        guardian = _newGuardian;

        emit EventsLib.SetGuardian(_msgSender(), _newGuardian);

        delete pendingGuardian;
    }

    /// @dev Sets the cap of the market.
    function _setCap(IERC4626 _market, uint184 _supplyCap) internal virtual {
        MarketConfig storage marketConfig = config[_market];

        if (_supplyCap > 0) {
            if (!marketConfig.enabled) {
                withdrawQueue.push(_market);

                if (withdrawQueue.length > ConstantsLib.MAX_QUEUE_LENGTH) revert ErrorsLib.MaxQueueLengthExceeded();

                marketConfig.enabled = true;

                // Take into account assets of the new market without applying a fee.
                _updateLastTotalAssets(lastTotalAssets + _expectedSupplyAssets(_market, address(this)));

                emit EventsLib.SetWithdrawQueue(msg.sender, withdrawQueue);
            }

            marketConfig.removableAt = 0;
            IERC20(asset()).approve(address(_market), 0);
        }

        marketConfig.cap = _supplyCap;
        // one time approval, so market can pull any amount of tokens from MetaMorpho in a future
        IERC20(asset()).approve(address(_market), type(uint256).max);
        emit EventsLib.SetCap(_msgSender(), _market, _supplyCap);

        delete pendingCap[_market];
    }

    /* LIQUIDITY ALLOCATION */

    /// @dev Supplies `assets` to Morpho.
    function _supplyMorpho(uint256 _assets) internal virtual {
        for (uint256 i; i < supplyQueue.length; ++i) {
            IERC4626 market = supplyQueue[i];

            uint256 supplyCap = config[market].cap;
            if (supplyCap == 0) continue;

            // `supplyAssets` needs to be rounded up for `toSupply` to be rounded down.
            uint256 supplyShares = market.balanceOf(address(this));
            uint256 supplyAssets = market.convertToAssets(supplyShares);

            uint256 toSupply = UtilsLib.min(UtilsLib.zeroFloorSub(supplyCap, supplyAssets), _assets);

            if (toSupply > 0) {
                // Using try/catch to skip markets that revert.
                try market.deposit(toSupply, address(this)) {
                    _assets -= toSupply;
                } catch {
                }
            }

            if (_assets == 0) return;
        }

        if (_assets != 0) revert ErrorsLib.AllCapsReached();
    }

    /// @dev Withdraws `assets` from Morpho.
    function _withdrawMorpho(uint256 _assets) internal virtual {
        for (uint256 i; i < withdrawQueue.length; ++i) {
            IERC4626 market = withdrawQueue[i];

            // original implementation were using `_accruedSupplyBalance` which does not care about liquidity
            // now, liquidity is considered by using `maxWithdraw`
            uint256 toWithdraw = UtilsLib.min(market.maxWithdraw(address(this)), _assets);

            if (toWithdraw > 0) {
                // Using try/catch to skip markets that revert.
                try market.withdraw(toWithdraw, address(this), address(this)) {
                    _assets -= toWithdraw;
                } catch {
                }
            }

            if (_assets == 0) return;
        }

        if (_assets != 0) revert ErrorsLib.NotEnoughLiquidity();
    }

    /// @dev Simulates a withdraw of `assets` from Morpho.
    /// @return The remaining assets to be withdrawn.
    function _simulateWithdrawMorpho(uint256 _assets) internal view virtual returns (uint256) {
        for (uint256 i; i < withdrawQueue.length; ++i) {
            IERC4626 market = withdrawQueue[i];

            _assets = UtilsLib.zeroFloorSub(_assets, market.maxWithdraw(address(this)));

            if (_assets == 0) break;
        }

        return _assets;
    }

    /* FEE MANAGEMENT */

    /// @dev Updates `lastTotalAssets` to `updatedTotalAssets`.
    function _updateLastTotalAssets(uint256 _updatedTotalAssets) internal virtual {
        lastTotalAssets = _updatedTotalAssets;

        emit EventsLib.UpdateLastTotalAssets(_updatedTotalAssets);
    }

    /// @dev Accrues the fee and mints the fee shares to the fee recipient.
    /// @return newTotalAssets The vaults total assets after accruing the interest.
    function _accrueFee() internal virtual returns (uint256 newTotalAssets) {
        uint256 feeShares;
        (feeShares, newTotalAssets) = _accruedFeeShares();

        if (feeShares != 0) _mint(feeRecipient, feeShares);

        emit EventsLib.AccrueInterest(newTotalAssets, feeShares);
    }

    /// @dev Computes and returns the fee shares (`feeShares`) to mint and the new vault's total assets
    /// (`newTotalAssets`).
    function _accruedFeeShares() internal view virtual returns (uint256 feeShares, uint256 newTotalAssets) {
        newTotalAssets = totalAssets();

        uint256 totalInterest = UtilsLib.zeroFloorSub(newTotalAssets, lastTotalAssets);
        if (totalInterest != 0 && fee != 0) {
            // It is acknowledged that `feeAssets` may be rounded down to 0 if `totalInterest * fee < WAD`.
            uint256 feeAssets = totalInterest.mulDiv(fee, WAD);
            // The fee assets is subtracted from the total assets in this calculation to compensate for the fact
            // that total assets is already increased by the total interest (including the fee assets).
            feeShares =
                _convertToSharesWithTotals(feeAssets, totalSupply(), newTotalAssets - feeAssets, Math.Rounding.Floor);
        }
    }

    /// @notice Returns the expected supply assets balance of `user` on a market after having accrued interest.
    function _expectedSupplyAssets(IERC4626 _market, address _user) internal view virtual returns (uint256 assets) {
        assets = _market.convertToAssets(_market.balanceOf(_user));
    }

    function _update(address _from, address _to, uint256 _value) internal virtual override {
        // on deposit, claim must be first action, new user should not get reward

        // on withdraw, claim must can be first action, user that is leaving should get rewards
        // immediate deposit-withdraw operation will not abused it, because before deposit all rewards will be
        // claimed, so on withdraw on the same block no additional rewards will be generated.

        // transfer shares is basically withdraw->deposit, so claiming rewards should be done before any state changes

        claimRewards();

        super._update(_from, _to, _value);

        if (_value == 0) return;
        
        _afterTokenTransfer(_from, _to, _value);
    }

    function _afterTokenTransfer(address _from, address _to, uint256 _value) internal virtual override {
        if (_value == 0) return;

        require(!_lock, ErrorsLib.NotificationDispatchError());
        _lock = true;

        address[] memory receivers = INCENTIVES_MODULE.getNotificationReceivers();

        uint256 total = totalSupply();
        uint256 senderBalance = _from == address(0) ? 0 : balanceOf(_from);
        uint256 recipientBalance = _to == address(0) ? 0 : balanceOf(_to);

        for(uint256 i; i < receivers.length; i++) {
            try INotificationReceiver(receivers[i]).afterTokenTransfer({
                _sender: _from,
                _senderBalance: senderBalance,
                _recipient: _to,
                _recipientBalance: recipientBalance,
                _totalSupply: total,
                 _amount: _value
            }) {
                // notification send
            } catch {
                // do not revert on invalid notification
            }
        }

        _lock = false;
    }
}
