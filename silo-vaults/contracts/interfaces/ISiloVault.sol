// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IERC20Permit} from "openzeppelin5/token/ERC20/extensions/ERC20Permit.sol";
import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {MarketConfig, PendingUint192, PendingAddress, ArbitraryLossThreshold} from "../libraries/PendingLib.sol";
import {IVaultIncentivesModule} from "./IVaultIncentivesModule.sol";

struct MarketAllocation {
    /// @notice The market to allocate.
    IERC4626 market;
    /// @notice The amount of assets to allocate.
    uint256 assets;
}

interface IMulticall {
    function multicall(bytes[] calldata) external returns (bytes[] memory);
}

interface IOwnable {
    function owner() external view returns (address);
    function transferOwnership(address) external;
    function renounceOwnership() external;
    function acceptOwnership() external;
    function pendingOwner() external view returns (address);
}

/// @dev This interface is used for factorizing ISiloVaultStaticTyping and ISiloVault.
/// @dev Consider using the ISiloVault interface instead of this one.
interface ISiloVaultBase {
    /// @notice OpenZeppelin decimals offset used by the ERC4626 implementation.
    /// @dev Calculated to be (24 - underlyingDecimals) at construction, so the initial conversion rate maximizes
    /// precision between shares and assets. Max `underlyingDecimals` is 18, so the minimum `DECIMALS_OFFSET` is 6.
    function DECIMALS_OFFSET() external view returns (uint8);

    /// @notice Default acceptable loss when depositing to market
    /// @dev For manipulated vault/market (ie. during first deposit attack), this loss will be huge.
    /// This threshold prevents SiloVault from losing funds in compromised markets with inflated shares to assets rate.
    /// This value can be changed by vault owner/guardian if needed.
    function DEFAULT_LOST_THRESHOLD() external view returns (uint256);

    /// @notice Incentives module for the vault.
    /// @dev Stores configuration for each market incentives claiming logic and
    /// notification receivers that will be notified when a vault's balance changes.
    function INCENTIVES_MODULE() external view returns (IVaultIncentivesModule);

    /// @notice method for claiming and distributing incentives rewards for all vault users
    function claimRewards() external;

    /// @notice Returns whether the reentrancy guard is entered.
    function reentrancyGuardEntered() external view returns (bool);

    /// @notice The address of the curator.
    function curator() external view returns (address);

    /// @notice Stores whether an address is an allocator or not.
    function isAllocator(address _target) external view returns (bool);

    /// @notice The current guardian. Can be set even without the timelock set.
    function guardian() external view returns (address);

    /// @notice The current fee.
    function fee() external view returns (uint96);

    /// @notice The fee recipient.
    function feeRecipient() external view returns (address);

    /// @notice The current timelock.
    function timelock() external view returns (uint256);

    /// @dev Stores the order of markets on which liquidity is supplied upon deposit.
    /// @dev Can contain any market. A market is skipped as soon as its supply cap is reached.
    function supplyQueue(uint256) external view returns (IERC4626);

    /// @notice Returns the length of the supply queue.
    function supplyQueueLength() external view returns (uint256);

    /// @dev Stores the order of markets from which liquidity is withdrawn upon withdrawal.
    /// @dev Always contain all non-zero cap markets as well as all markets on which the vault supplies liquidity,
    /// without duplicate.
    function withdrawQueue(uint256) external view returns (IERC4626);

    /// @notice Returns the length of the withdraw queue.
    function withdrawQueueLength() external view returns (uint256);

    /// @notice Stores the total assets managed by this vault when the fee was last accrued.
    /// @dev May be greater than `totalAssets()` due to removal of markets with non-zero supply or socialized bad debt.
    /// This difference will decrease the fee accrued until one of the functions updating `lastTotalAssets` is
    /// triggered (deposit/mint/withdraw/redeem/setFee/setFeeRecipient).
    function lastTotalAssets() external view returns (uint256);

    /// @notice Submits a `newTimelock`.
    /// @dev Warning: Reverts if a timelock is already pending. Revoke the pending timelock to overwrite it.
    /// @dev In case the new timelock is higher than the current one, the timelock is set immediately.
    function submitTimelock(uint256 _newTimelock) external;

    /// @notice Accepts the pending timelock.
    function acceptTimelock() external;

    /// @notice Revokes the pending timelock.
    /// @dev Does not revert if there is no pending timelock.
    function revokePendingTimelock() external;

    /// @notice Submits a `newSupplyCap` for the market defined by `marketParams`.
    /// @dev Warning: Reverts if a cap is already pending. Revoke the pending cap to overwrite it.
    /// @dev Warning: Reverts if a market removal is pending.
    /// @dev In case the new cap is lower than the current one, the cap is set immediately.
    function submitCap(IERC4626 _market, uint256 _newSupplyCap) external;

    /// @notice Set loss threshold for the market. No timelock.
    function setArbitraryLossThreshold(IERC4626 _market, uint256 _loss) external;

    /// @notice Accepts the pending cap of the market defined by `marketParams`.
    function acceptCap(IERC4626 _market) external;

    /// @notice Revokes the pending cap of the market defined by `market`.
    /// @dev Does not revert if there is no pending cap.
    function revokePendingCap(IERC4626 _market) external;

    /// @notice Submits a forced market removal from the vault, eventually losing all funds supplied to the market.
    /// @notice Funds can be recovered by enabling this market again and withdrawing from it (using `reallocate`),
    /// but funds will be distributed pro-rata to the shares at the time of withdrawal, not at the time of removal.
    /// @notice This forced removal is expected to be used as an emergency process in case a market constantly reverts.
    /// To softly remove a sane market, the curator role is expected to bundle a reallocation that empties the market
    /// first (using `reallocate`), followed by the removal of the market (using `updateWithdrawQueue`).
    /// @dev Warning: Removing a market with non-zero supply will instantly impact the vault's price per share.
    /// @dev Warning: Reverts for non-zero cap or if there is a pending cap. Successfully submitting a zero cap will
    /// prevent such reverts.
    function submitMarketRemoval(IERC4626 _market) external;

    /// @notice Revokes the pending removal of the market defined by `market`.
    /// @dev Does not revert if there is no pending market removal.
    function revokePendingMarketRemoval(IERC4626 _market) external;

    /// @notice Submits a `newGuardian`.
    /// @notice Warning: a malicious guardian could disrupt the vault's operation, and would have the power to revoke
    /// any pending guardian.
    /// @dev In case there is no guardian, the guardian is set immediately.
    /// @dev Warning: Submitting a guardian will overwrite the current pending guardian.
    function submitGuardian(address _newGuardian) external;

    /// @notice Accepts the pending guardian.
    function acceptGuardian() external;

    /// @notice Revokes the pending guardian.
    function revokePendingGuardian() external;

    /// @notice Sets `newAllocator` as an allocator or not (`newIsAllocator`).
    function setIsAllocator(address _newAllocator, bool _newIsAllocator) external;

    /// @notice Sets `curator` to `newCurator`.
    function setCurator(address _newCurator) external;

    /// @notice Sets the `fee` to `newFee`.
    function setFee(uint256 _newFee) external;

    /// @notice Sets `feeRecipient` to `newFeeRecipient`.
    function setFeeRecipient(address _newFeeRecipient) external;

    /// @notice Sets `supplyQueue` to `newSupplyQueue`.
    /// @param _newSupplyQueue is an array of enabled markets, and can contain duplicate markets, but it would only
    /// increase the cost of depositing to the vault.
    function setSupplyQueue(IERC4626[] calldata _newSupplyQueue) external;

    /// @notice Updates the withdraw queue. Some markets can be removed, but no market can be added.
    /// @notice Removing a market requires the vault to have 0 supply on it, or to have previously submitted a removal
    /// for this market (with the function `submitMarketRemoval`).
    /// @notice Warning: Anyone can supply on behalf of the vault so the call to `updateWithdrawQueue` that expects a
    /// market to be empty can be griefed by a front-run. To circumvent this, the allocator can simply bundle a
    /// reallocation that withdraws max from this market with a call to `updateWithdrawQueue`.
    /// @dev Warning: Removing a market with supply will decrease the fee accrued until one of the functions updating
    /// `lastTotalAssets` is triggered (deposit/mint/withdraw/redeem/setFee/setFeeRecipient).
    /// @dev Warning: `updateWithdrawQueue` is not idempotent. Submitting twice the same tx will change the queue twice.
    /// @param _indexes The indexes of each market in the previous withdraw queue, in the new withdraw queue's order.
    function updateWithdrawQueue(uint256[] calldata _indexes) external;

    /// @notice Reallocates the vault's liquidity so as to reach a given allocation of assets on each given market.
    /// @dev The behavior of the reallocation can be altered by state changes, including:
    /// - Deposits on the vault that supplies to markets that are expected to be supplied to during reallocation.
    /// - Withdrawals from the vault that withdraws from markets that are expected to be withdrawn from during
    /// reallocation.
    /// - Donations to the vault on markets that are expected to be supplied to during reallocation.
    /// - Withdrawals from markets that are expected to be withdrawn from during reallocation.
    /// @dev Sender is expected to pass `assets = type(uint256).max` with the last MarketAllocation of `allocations` to
    /// supply all the remaining withdrawn liquidity, which would ensure that `totalWithdrawn` = `totalSupplied`.
    /// @dev A supply in a reallocation step will make the reallocation revert if the amount is greater than the net
    /// amount from previous steps (i.e. total withdrawn minus total supplied). This function reverts if the assets
    /// to be deposited would cause the SiloVault's deposits of the corresponding market to exceed its supply cap.
    function reallocate(MarketAllocation[] calldata _allocations) external;

    /// @notice Syncs the balance tracker for the market.
    function syncBalanceTracker(IERC4626, uint256, bool) external;
}

/// @dev This interface is inherited by SiloVault so that function signatures are checked by the compiler.
/// @dev Consider using the ISiloVault interface instead of this one.
interface ISiloVaultStaticTyping is ISiloVaultBase {
    /// @notice Returns the current configuration of each market.
    function config(IERC4626) external view returns (uint184 cap, bool enabled, uint64 removableAt);

    /// @notice Returns the pending guardian.
    function pendingGuardian() external view returns (address guardian, uint64 validAt);

    /// @notice Returns the pending cap for each market.
    function pendingCap(IERC4626) external view returns (uint192 value, uint64 validAt);

    /// @notice Returns the pending timelock.
    function pendingTimelock() external view returns (uint192 value, uint64 validAt);
}

/// @title IMetaMorpho
/// @dev Forked with gratitude from Morpho Labs.
/// @author Silo Labs
/// @custom:contact security@silo.finance
/// @dev Use this interface for SiloVault to have access to all the functions with the appropriate function signatures.
interface ISiloVault is ISiloVaultBase, IERC4626, IERC20Permit, IOwnable, IMulticall {
    /// @notice Returns the current configuration of each market.
    function config(IERC4626) external view returns (MarketConfig memory);

    /// @notice Returns the arbitrary loss threshold for the market.
    function arbitraryLossThreshold(IERC4626) external view returns (ArbitraryLossThreshold memory);

    /// @notice Returns the pending guardian.
    function pendingGuardian() external view returns (PendingAddress memory);

    /// @notice Returns the pending cap for each market.
    function pendingCap(IERC4626) external view returns (PendingUint192 memory);

    /// @notice Returns the pending timelock.
    function pendingTimelock() external view returns (PendingUint192 memory);

    /// @notice Returns the allocation of assets for the market.
    function balanceTracker(IERC4626) external view returns (uint256);
}
