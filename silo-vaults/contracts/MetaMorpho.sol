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

    /* CONSTRUCTOR */

    /// @dev Initializes the contract.
    /// @param owner The owner of the contract.
    /// @param initialTimelock The initial timelock.
    /// @param _asset The address of the underlying asset.
    /// @param _name The name of the vault.
    /// @param _symbol The symbol of the vault.
    constructor(
        address owner,
        uint256 initialTimelock,
        address _asset,
        string memory _name,
        string memory _symbol
    ) ERC4626(IERC20(_asset)) ERC20Permit(_name) ERC20(_name, _symbol) Ownable(owner) {
        require(_asset != address(0), ErrorsLib.ZeroAddress());

        DECIMALS_OFFSET = uint8(UtilsLib.zeroFloorSub(18, IERC20Metadata(_asset).decimals()));

        _checkTimelockBounds(initialTimelock);
        _setTimelock(initialTimelock);
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
    modifier afterTimelock(uint256 validAt) {
        if (validAt == 0) revert ErrorsLib.NoPendingValue();
        if (block.timestamp < validAt) revert ErrorsLib.TimelockNotElapsed();

        _;
    }

    /* ONLY OWNER FUNCTIONS */

    /// @inheritdoc IMetaMorphoBase
    function setCurator(address newCurator) external virtual onlyOwner {
        if (newCurator == curator) revert ErrorsLib.AlreadySet();

        curator = newCurator;

        emit EventsLib.SetCurator(newCurator);
    }

    /// @inheritdoc IMetaMorphoBase
    function setIsAllocator(address newAllocator, bool newIsAllocator) external virtual onlyOwner {
        if (isAllocator[newAllocator] == newIsAllocator) revert ErrorsLib.AlreadySet();

        isAllocator[newAllocator] = newIsAllocator;

        emit EventsLib.SetIsAllocator(newAllocator, newIsAllocator);
    }

    /// @inheritdoc IMetaMorphoBase
    function setSkimRecipient(address newSkimRecipient) external virtual onlyOwner {
        if (newSkimRecipient == skimRecipient) revert ErrorsLib.AlreadySet();

        skimRecipient = newSkimRecipient;

        emit EventsLib.SetSkimRecipient(newSkimRecipient);
    }

    /// @inheritdoc IMetaMorphoBase
    function submitTimelock(uint256 newTimelock) external virtual onlyOwner {
        if (newTimelock == timelock) revert ErrorsLib.AlreadySet();
        if (pendingTimelock.validAt != 0) revert ErrorsLib.AlreadyPending();
        _checkTimelockBounds(newTimelock);

        if (newTimelock > timelock) {
            _setTimelock(newTimelock);
        } else {
            // Safe "unchecked" cast because newTimelock <= MAX_TIMELOCK.
            pendingTimelock.update(uint184(newTimelock), timelock);

            emit EventsLib.SubmitTimelock(newTimelock);
        }
    }

    /// @inheritdoc IMetaMorphoBase
    function setFee(uint256 newFee) external virtual onlyOwner {
        if (newFee == fee) revert ErrorsLib.AlreadySet();
        if (newFee > ConstantsLib.MAX_FEE) revert ErrorsLib.MaxFeeExceeded();
        if (newFee != 0 && feeRecipient == address(0)) revert ErrorsLib.ZeroFeeRecipient();

        // Accrue fee using the previous fee set before changing it.
        _updateLastTotalAssets(_accrueFee());

        // Safe "unchecked" cast because newFee <= MAX_FEE.
        fee = uint96(newFee);

        emit EventsLib.SetFee(_msgSender(), fee);
    }

    /// @inheritdoc IMetaMorphoBase
    function setFeeRecipient(address newFeeRecipient) external virtual onlyOwner {
        if (newFeeRecipient == feeRecipient) revert ErrorsLib.AlreadySet();
        if (newFeeRecipient == address(0) && fee != 0) revert ErrorsLib.ZeroFeeRecipient();

        // Accrue fee to the previous fee recipient set before changing it.
        _updateLastTotalAssets(_accrueFee());

        feeRecipient = newFeeRecipient;

        emit EventsLib.SetFeeRecipient(newFeeRecipient);
    }

    /// @inheritdoc IMetaMorphoBase
    function submitGuardian(address newGuardian) external virtual onlyOwner {
        if (newGuardian == guardian) revert ErrorsLib.AlreadySet();
        if (pendingGuardian.validAt != 0) revert ErrorsLib.AlreadyPending();

        if (guardian == address(0)) {
            _setGuardian(newGuardian);
        } else {
            pendingGuardian.update(newGuardian, timelock);

            emit EventsLib.SubmitGuardian(newGuardian);
        }
    }

    /* ONLY CURATOR FUNCTIONS */

    /// @inheritdoc IMetaMorphoBase
    function submitCap(IERC4626 market, uint256 newSupplyCap) external virtual onlyCuratorRole {
        if (market.asset() != asset()) revert ErrorsLib.InconsistentAsset(market);
        if (pendingCap[market].validAt != 0) revert ErrorsLib.AlreadyPending();
        if (config[market].removableAt != 0) revert ErrorsLib.PendingRemoval();
        uint256 supplyCap = config[market].cap;
        if (newSupplyCap == supplyCap) revert ErrorsLib.AlreadySet();

        if (newSupplyCap < supplyCap) {
            _setCap(market, SafeCast.toUint184(newSupplyCap));
        } else {
            pendingCap[market].update(SafeCast.toUint184(newSupplyCap), timelock);

            emit EventsLib.SubmitCap(_msgSender(), market, newSupplyCap);
        }
    }

    /// @inheritdoc IMetaMorphoBase
    function submitMarketRemoval(IERC4626 market) external virtual onlyCuratorRole {
        if (config[market].removableAt != 0) revert ErrorsLib.AlreadyPending();
        if (config[market].cap != 0) revert ErrorsLib.NonZeroCap();
        if (!config[market].enabled) revert ErrorsLib.MarketNotEnabled(market);
        if (pendingCap[market].validAt != 0) revert ErrorsLib.PendingCap(market);

        // Safe "unchecked" cast because timelock <= MAX_TIMELOCK.
        config[market].removableAt = uint64(block.timestamp + timelock);

        emit EventsLib.SubmitMarketRemoval(_msgSender(), market);
    }

    /* ONLY ALLOCATOR FUNCTIONS */

    /// @inheritdoc IMetaMorphoBase
    function setSupplyQueue(IERC4626[] calldata newSupplyQueue) external virtual onlyAllocatorRole {
        uint256 length = newSupplyQueue.length;

        if (length > ConstantsLib.MAX_QUEUE_LENGTH) revert ErrorsLib.MaxQueueLengthExceeded();

        for (uint256 i; i < length; ++i) {
            IERC4626 market = newSupplyQueue[i];
            if (config[market].cap == 0) revert ErrorsLib.UnauthorizedMarket(market);
        }

        supplyQueue = newSupplyQueue;

        emit EventsLib.SetSupplyQueue(_msgSender(), newSupplyQueue);
    }

    /// @inheritdoc IMetaMorphoBase
    function updateWithdrawQueue(uint256[] calldata indexes) external virtual onlyAllocatorRole {
        uint256 newLength = indexes.length;
        uint256 currLength = withdrawQueue.length;

        bool[] memory seen = new bool[](currLength);
        IERC4626[] memory newWithdrawQueue = new IERC4626[](newLength);

        for (uint256 i; i < newLength; ++i) {
            uint256 prevIndex = indexes[i];

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
    function reallocate(MarketAllocation[] calldata allocations) external virtual onlyAllocatorRole {
        uint256 totalSupplied;
        uint256 totalWithdrawn;
        for (uint256 i; i < allocations.length; ++i) {
            MarketAllocation memory allocation = allocations[i];

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
    function revokePendingCap(IERC4626 market) external virtual onlyCuratorOrGuardianRole {
        delete pendingCap[market];

        emit EventsLib.RevokePendingCap(_msgSender(), market);
    }

    /// @inheritdoc IMetaMorphoBase
    function revokePendingMarketRemoval(IERC4626 market) external virtual onlyCuratorOrGuardianRole {
        delete config[market].removableAt;

        emit EventsLib.RevokePendingMarketRemoval(_msgSender(), market);
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
    function acceptCap(IERC4626 market)
        external
        virtual
        afterTimelock(pendingCap[market].validAt)
    {
        // Safe "unchecked" cast because pendingCap <= type(uint184).max.
        _setCap(market, uint184(pendingCap[market].value));
    }

    /// @inheritdoc IMetaMorphoBase
    function skim(address token) external virtual {
        if (skimRecipient == address(0)) revert ErrorsLib.ZeroAddress();

        uint256 amount = IERC20(token).balanceOf(address(this));

        IERC20(token).safeTransfer(skimRecipient, amount);

        emit EventsLib.Skim(_msgSender(), token, amount);
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
    function maxWithdraw(address owner) public view virtual override returns (uint256 assets) {
        (assets,,) = _maxWithdraw(owner);
    }

    /// @inheritdoc IERC4626
    /// @dev Warning: May be lower than the actual amount of shares that can be redeemed by `owner` due to conversion
    /// roundings between shares and assets.
    function maxRedeem(address owner) public view virtual override returns (uint256) {
        (uint256 assets, uint256 newTotalSupply, uint256 newTotalAssets) = _maxWithdraw(owner);

        return _convertToSharesWithTotals(assets, newTotalSupply, newTotalAssets, Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 assets, address receiver) public virtual override returns (uint256 shares) {
        uint256 newTotalAssets = _accrueFee();

        // Update `lastTotalAssets` to avoid an inconsistent state in a re-entrant context.
        // It is updated again in `_deposit`.
        lastTotalAssets = newTotalAssets;

        shares = _convertToSharesWithTotals(assets, totalSupply(), newTotalAssets, Math.Rounding.Floor);

        _deposit(_msgSender(), receiver, assets, shares);
    }

    /// @inheritdoc IERC4626
    function mint(uint256 shares, address receiver) public virtual override returns (uint256 assets) {
        uint256 newTotalAssets = _accrueFee();

        // Update `lastTotalAssets` to avoid an inconsistent state in a re-entrant context.
        // It is updated again in `_deposit`.
        lastTotalAssets = newTotalAssets;

        assets = _convertToAssetsWithTotals(shares, totalSupply(), newTotalAssets, Math.Rounding.Ceil);

        _deposit(_msgSender(), receiver, assets, shares);
    }

    /// @inheritdoc IERC4626
    function withdraw(uint256 assets, address receiver, address owner)
        public
        virtual
        override
        returns (uint256 shares)
    {
        uint256 newTotalAssets = _accrueFee();

        // Do not call expensive `maxWithdraw` and optimistically withdraw assets.

        shares = _convertToSharesWithTotals(assets, totalSupply(), newTotalAssets, Math.Rounding.Ceil);

        // `newTotalAssets - assets` may be a little off from `totalAssets()`.
        _updateLastTotalAssets(UtilsLib.zeroFloorSub(newTotalAssets, assets));

        _withdraw(_msgSender(), receiver, owner, assets, shares);
    }

    /// @inheritdoc IERC4626
    function redeem(uint256 shares, address receiver, address owner) public virtual override returns (uint256 assets) {
        uint256 newTotalAssets = _accrueFee();

        // Do not call expensive `maxRedeem` and optimistically redeem shares.

        assets = _convertToAssetsWithTotals(shares, totalSupply(), newTotalAssets, Math.Rounding.Floor);

        // `newTotalAssets - assets` may be a little off from `totalAssets()`.
        _updateLastTotalAssets(UtilsLib.zeroFloorSub(newTotalAssets, assets));

        _withdraw(_msgSender(), receiver, owner, assets, shares);
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
    function _maxWithdraw(address owner)
        internal
        view
        virtual
        returns (uint256 assets, uint256 newTotalSupply, uint256 newTotalAssets)
    {
        uint256 feeShares;
        (feeShares, newTotalAssets) = _accruedFeeShares();
        newTotalSupply = totalSupply() + feeShares;

        assets = _convertToAssetsWithTotals(balanceOf(owner), newTotalSupply, newTotalAssets, Math.Rounding.Floor);
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
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view virtual override returns (uint256) {
        (uint256 feeShares, uint256 newTotalAssets) = _accruedFeeShares();

        return _convertToSharesWithTotals(assets, totalSupply() + feeShares, newTotalAssets, rounding);
    }

    /// @inheritdoc ERC4626
    /// @dev The accrual of performance fees is taken into account in the conversion.
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view virtual override returns (uint256) {
        (uint256 feeShares, uint256 newTotalAssets) = _accruedFeeShares();

        return _convertToAssetsWithTotals(shares, totalSupply() + feeShares, newTotalAssets, rounding);
    }

    /// @dev Returns the amount of shares that the vault would exchange for the amount of `assets` provided.
    /// @dev It assumes that the arguments `newTotalSupply` and `newTotalAssets` are up to date.
    function _convertToSharesWithTotals(
        uint256 assets,
        uint256 newTotalSupply,
        uint256 newTotalAssets,
        Math.Rounding rounding
    ) internal view virtual returns (uint256) {
        return assets.mulDiv(newTotalSupply + 10 ** _decimalsOffset(), newTotalAssets + 1, rounding);
    }

    /// @dev Returns the amount of assets that the vault would exchange for the amount of `shares` provided.
    /// @dev It assumes that the arguments `newTotalSupply` and `newTotalAssets` are up to date.
    function _convertToAssetsWithTotals(
        uint256 shares,
        uint256 newTotalSupply,
        uint256 newTotalAssets,
        Math.Rounding rounding
    ) internal view virtual returns (uint256) {
        return shares.mulDiv(newTotalAssets + 1, newTotalSupply + 10 ** _decimalsOffset(), rounding);
    }

    /// @inheritdoc ERC4626
    /// @dev Used in mint or deposit to deposit the underlying asset to Morpho markets.
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal virtual override {
        super._deposit(caller, receiver, assets, shares);

        _supplyMorpho(assets);

        // `lastTotalAssets + assets` may be a little off from `totalAssets()`.
        _updateLastTotalAssets(lastTotalAssets + assets);
    }

    /// @inheritdoc ERC4626
    /// @dev Used in redeem or withdraw to withdraw the underlying asset from Morpho markets.
    /// @dev Depending on 3 cases, reverts when withdrawing "too much" with:
    /// 1. NotEnoughLiquidity when withdrawing more than available liquidity.
    /// 2. ERC20InsufficientAllowance when withdrawing more than `caller`'s allowance.
    /// 3. ERC20InsufficientBalance when withdrawing more than `owner`'s balance.
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        virtual
        override
    {
        _withdrawMorpho(assets);

        super._withdraw(caller, receiver, owner, assets, shares);
    }

    /* INTERNAL */


    /// @dev Returns the vault's assets & corresponding shares supplied on the
    /// market defined by `market`, as well as the market's state.
    function _supplyBalance(IERC4626 market)
        internal
        view
        virtual
        returns (uint256 assets, uint256 shares)
    {
        shares = market.balanceOf(address(this));
        // we assume here, that in case of any interest on IERC4626, convertToAssets returns assets with interest
        assets = market.convertToAssets(shares);
    }

    /// @dev Reverts if `newTimelock` is not within the bounds.
    function _checkTimelockBounds(uint256 newTimelock) internal pure virtual {
        if (newTimelock > ConstantsLib.MAX_TIMELOCK) revert ErrorsLib.AboveMaxTimelock();
        if (newTimelock < ConstantsLib.MIN_TIMELOCK) revert ErrorsLib.BelowMinTimelock();
    }

    /// @dev Sets `timelock` to `newTimelock`.
    function _setTimelock(uint256 newTimelock) internal virtual {
        timelock = newTimelock;

        emit EventsLib.SetTimelock(_msgSender(), newTimelock);

        delete pendingTimelock;
    }

    /// @dev Sets `guardian` to `newGuardian`.
    function _setGuardian(address newGuardian) internal virtual {
        guardian = newGuardian;

        emit EventsLib.SetGuardian(_msgSender(), newGuardian);

        delete pendingGuardian;
    }

    /// @dev Sets the cap of the market.
    function _setCap(IERC4626 market, uint184 supplyCap) internal virtual {
        MarketConfig storage marketConfig = config[market];

        if (supplyCap > 0) {
            if (!marketConfig.enabled) {
                withdrawQueue.push(market);

                if (withdrawQueue.length > ConstantsLib.MAX_QUEUE_LENGTH) revert ErrorsLib.MaxQueueLengthExceeded();

                marketConfig.enabled = true;

                // Take into account assets of the new market without applying a fee.
                _updateLastTotalAssets(lastTotalAssets + _expectedSupplyAssets(market, address(this)));

                emit EventsLib.SetWithdrawQueue(msg.sender, withdrawQueue);
            }

            marketConfig.removableAt = 0;
            IERC20(asset()).approve(address(market), 0);
        }

        marketConfig.cap = supplyCap;
        IERC20(asset()).approve(address(market), type(uint256).max);
        emit EventsLib.SetCap(_msgSender(), market, supplyCap);

        delete pendingCap[market];
    }

    /* LIQUIDITY ALLOCATION */

    /// @dev Supplies `assets` to Morpho.
    function _supplyMorpho(uint256 assets) internal virtual {
        for (uint256 i; i < supplyQueue.length; ++i) {
            IERC4626 market = supplyQueue[i];

            uint256 supplyCap = config[market].cap;
            if (supplyCap == 0) continue;

            // `supplyAssets` needs to be rounded up for `toSupply` to be rounded down.
            uint256 supplyShares = market.balanceOf(address(this));
            uint256 supplyAssets = market.convertToAssets(supplyShares);

            uint256 toSupply = UtilsLib.min(UtilsLib.zeroFloorSub(supplyCap, supplyAssets), assets);

            if (toSupply > 0) {
                // Using try/catch to skip markets that revert.
                try market.deposit(toSupply, address(this)) {
                    assets -= toSupply;
                } catch {
                }
            }

            if (assets == 0) return;
        }

        if (assets != 0) revert ErrorsLib.AllCapsReached();
    }

    /// @dev Withdraws `assets` from Morpho.
    function _withdrawMorpho(uint256 assets) internal virtual {
        for (uint256 i; i < withdrawQueue.length; ++i) {
            IERC4626 market = withdrawQueue[i];

            // original implementation were using `_accruedSupplyBalance` which does not care about liquidity
            // now, liquidity is considered by using `maxWithdraw`
            uint256 toWithdraw = UtilsLib.min(market.maxWithdraw(address(this)), assets);

            if (toWithdraw > 0) {
                // Using try/catch to skip markets that revert.
                try market.withdraw(toWithdraw, address(this), address(this)) {
                    assets -= toWithdraw;
                } catch {
                }
            }

            if (assets == 0) return;
        }

        if (assets != 0) revert ErrorsLib.NotEnoughLiquidity();
    }

    /// @dev Simulates a withdraw of `assets` from Morpho.
    /// @return The remaining assets to be withdrawn.
    function _simulateWithdrawMorpho(uint256 assets) internal view virtual returns (uint256) {
        for (uint256 i; i < withdrawQueue.length; ++i) {
            IERC4626 market = withdrawQueue[i];

            assets = UtilsLib.zeroFloorSub(assets, market.maxWithdraw(address(this)));

            if (assets == 0) break;
        }

        return assets;
    }

    /* FEE MANAGEMENT */

    /// @dev Updates `lastTotalAssets` to `updatedTotalAssets`.
    function _updateLastTotalAssets(uint256 updatedTotalAssets) internal virtual {
        lastTotalAssets = updatedTotalAssets;

        emit EventsLib.UpdateLastTotalAssets(updatedTotalAssets);
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
}
