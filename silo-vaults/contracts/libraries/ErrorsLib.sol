// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

/// @title ErrorsLib
/// @dev Forked with gratitude from Morpho Labs.
/// @author Silo Labs
/// @custom:contact security@silo.finance
/// @notice Library exposing error messages.
library ErrorsLib {
    /// @notice Thrown when asset decimals is too big
    error NotSupportedDecimals();

    /// @notice Thrown when deposit generates zero shares
    error InputZeroShares();

    /// @notice Thrown on OutOfGas or revert() without any data
    error PossibleOutOfGas();

    /// @notice Thrown on reentering token transfer while notification are being dispatched
    error NotificationDispatchError();

    /// @notice Thrown on reentering
    error ReentrancyError();

    /// @notice Thrown when delegatecall on claiming rewards failed
    error ClaimRewardsFailed();

    /// @notice Thrown when the address passed is the zero address.
    error ZeroAddress();

    /// @notice Thrown when the result of a conversion is zero.
    error ZeroAssets();

    /// @notice Thrown when the result of a conversion is zero.
    error ZeroShares();

    /// @notice Thrown when the caller doesn't have the curator role.
    error NotCuratorRole();

    /// @notice Thrown when the caller doesn't have the allocator role.
    error NotAllocatorRole();

    /// @notice Thrown when the caller doesn't have the guardian role.
    error NotGuardianRole();

    /// @notice Thrown when the caller doesn't have the curator nor the guardian role.
    error NotCuratorNorGuardianRole();

    /// @notice Thrown when the `market` cannot be set in the supply queue.
    error UnauthorizedMarket(IERC4626 market);

    /// @notice Thrown when submitting a cap for a `market` whose loan token does not correspond to the underlying.
    /// asset.
    error InconsistentAsset(IERC4626 market);

    /// @notice Thrown when the supply cap has been exceeded on `market` during a reallocation of funds.
    error SupplyCapExceeded(IERC4626 market);

    /// @notice Thrown when the supply cap has been exceeded on `market` during a reallocation of funds.
    error InternalSupplyCapExceeded(IERC4626 market);

    /// @notice Thrown when the fee to set exceeds the maximum fee.
    error MaxFeeExceeded();

    /// @notice Thrown when the value is already set.
    error AlreadySet();

    /// @notice Thrown when a value is already pending.
    error AlreadyPending();

    /// @notice Thrown when submitting the removal of a market when there is a cap already pending on that market.
    error PendingCap(IERC4626 market);

    /// @notice Thrown when submitting a cap for a market with a pending removal.
    error PendingRemoval();

    /// @notice Thrown when submitting a market removal for a market with a non zero cap.
    error NonZeroCap();

    /// @notice Thrown when `market` is a duplicate in the new withdraw queue to set.
    error DuplicateMarket(IERC4626 market);

    /// @notice Thrown when `market` is missing in the updated withdraw queue and the market has a non-zero cap set.
    error InvalidMarketRemovalNonZeroCap(IERC4626 market);

    /// @notice Thrown when `market` is missing in the updated withdraw queue and the market has a non-zero supply.
    error InvalidMarketRemovalNonZeroSupply(IERC4626 market);

    /// @notice Thrown when `market` is missing in the updated withdraw queue and the market is not yet disabled.
    error InvalidMarketRemovalTimelockNotElapsed(IERC4626 market);

    /// @notice Thrown when there's no pending value to set.
    error NoPendingValue();

    /// @notice Thrown when the requested liquidity cannot be withdrawn from Morpho.
    error NotEnoughLiquidity();

    /// @notice Thrown when interacting with a non previously enabled `market`.
    /// @notice Thrown when attempting to reallocate or set flows to non-zero values for a non-enabled market.
    error MarketNotEnabled(IERC4626 market);

    /// @notice Thrown when the submitted timelock is above the max timelock.
    error AboveMaxTimelock();

    /// @notice Thrown when the submitted timelock is below the min timelock.
    error BelowMinTimelock();

    /// @notice Thrown when the timelock is not elapsed.
    error TimelockNotElapsed();

    /// @notice Thrown when too many markets are in the withdraw queue.
    error MaxQueueLengthExceeded();

    /// @notice Thrown when setting the fee to a non zero value while the fee recipient is the zero address.
    error ZeroFeeRecipient();

    /// @notice Thrown when the amount withdrawn is not exactly the amount supplied.
    error InconsistentReallocation();

    /// @notice Thrown when all caps have been reached.
    error AllCapsReached();

    /// @notice Thrown when the `msg.sender` is not the admin nor the owner of the vault.
    error NotAdminNorVaultOwner();

    /// @notice Thrown when the reallocation fee given is wrong.
    error IncorrectFee();

    /// @notice Thrown when `withdrawals` is empty.
    error EmptyWithdrawals();

    /// @notice Thrown when `withdrawals` contains a duplicate or is not sorted.
    error InconsistentWithdrawals();

    /// @notice Thrown when the deposit market is in `withdrawals`.
    error DepositMarketInWithdrawals();

    /// @notice Thrown when attempting to withdraw zero of a market.
    error WithdrawZero(IERC4626 market);

    /// @notice Thrown when attempting to set max inflow/outflow above the MAX_SETTABLE_FLOW_CAP.
    error MaxSettableFlowCapExceeded();

    /// @notice Thrown when attempting to withdraw more than the available supply of a market.
    error NotEnoughSupply(IERC4626 market);

    /// @notice Thrown when attempting to withdraw more than the max outflow of a market.
    error MaxOutflowExceeded(IERC4626 market);

    /// @notice Thrown when attempting to supply more than the max inflow of a market.
    error MaxInflowExceeded(IERC4626 market);

    /// @notice Thrown when projected withdraw is much less than what user deposit.
    error AssetLoss(uint256 loss);

    /// @notice Thrown when the override is invalid.
    error InvalidOverride();

    /// @notice Thrown when the caller doesn't have the owner role.
    error NotOwner();

    /// @notice Thrown if withdrawn assets are not equal to the sum of the balance before and the withdrawn amount.
    error FailedToWithdraw();

    function revertBytes(bytes memory _errMsg) internal pure {
        if (_errMsg.length > 0) {
            assembly { // solhint-disable-line no-inline-assembly
                revert(add(32, _errMsg), mload(_errMsg))
            }
        }

        revert();
    }
}
