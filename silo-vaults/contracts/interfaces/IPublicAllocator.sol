// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {ISiloVault} from "./ISiloVault.sol";

    /// @dev Max settable flow cap, such that caps can always be stored on 128 bits.
    /// @dev The actual max possible flow cap is type(uint128).max / 2
    uint128 constant MAX_SETTABLE_FLOW_CAP = type(uint128).max / 2;

    struct FlowCaps {
        /// @notice The maximum allowed inflow in a market.
        uint128 maxIn;
        /// @notice The maximum allowed outflow in a market.
        uint128 maxOut;
    }

    struct FlowCapsConfig {
        /// @notice Market for which to change flow caps.
        IERC4626 market;
        /// @notice New flow caps for this market.
        FlowCaps caps;
    }

    struct Withdrawal {
        /// @notice The market from which to withdraw.
        IERC4626 market;
        /// @notice The amount to withdraw.
        uint128 amount;
    }

/// @dev This interface is used for factorizing IPublicAllocatorStaticTyping and IPublicAllocator.
/// @dev Consider using the IPublicAllocator interface instead of this one.
interface IPublicAllocatorBase {
    /// @notice The admin for a given vault.
    function admin(ISiloVault _vault) external view returns (address);

    /// @notice The current ETH fee for a given vault.
    function fee(ISiloVault _vault) external view returns (uint256);

    /// @notice The accrued ETH fee for a given vault.
    function accruedFee(ISiloVault _vault) external view returns (uint256);

    /// @notice Reallocates from a list of markets to one market.
    /// @param _vault The SiloVault vault to reallocate.
    /// @param _withdrawals The markets to withdraw from,and the amounts to withdraw.
    /// @param _supplyMarket The market receiving total withdrawn to.
    /// @dev Will call SiloVault's `reallocate`.
    /// @dev Checks that the flow caps are respected.
    /// @dev Will revert when `withdrawals` contains a duplicate or is not sorted.
    /// @dev Will revert if `withdrawals` contains the supply market.
    /// @dev Will revert if a withdrawal amount is larger than available liquidity.
    /// @dev flow is as follow:
    /// - iterating over withdrawals markets
    ///   - increase flowCaps.maxIn by withdrawal amount for market
    ///   - decrease flowCaps.maxOut by withdrawal amount for market
    ///   - put market into allocation list with amount equal `market deposit - withdrawal amount`
    ///   - increase total amount to withdraw
    /// - after iteration, with allocation list ready, final steps are:
    ///   - decrease flowCaps.maxIn by total withdrawal amount for `supplyMarket`
    ///   - increase flowCaps.maxOut by total withdrawal amount for `supplyMarket`
    ///   - add `supplyMarket` to allocation list with MAX assets
    ///   - run `reallocate` on SiloVault
    function reallocateTo(ISiloVault _vault, Withdrawal[] calldata _withdrawals, IERC4626 _supplyMarket)
        external
        payable;

    /// @notice Sets the admin for a given vault.
    function setAdmin(ISiloVault _vault, address _newAdmin) external;

    /// @notice Sets the fee for a given vault.
    function setFee(ISiloVault _vault, uint256 _newFee) external;

    /// @notice Transfers the current balance to `feeRecipient` for a given vault.
    function transferFee(ISiloVault _vault, address payable _feeRecipient) external;

    /// @notice Sets the maximum inflow and outflow through public allocation for some markets for a given vault.
    /// @dev Max allowed inflow/outflow is MAX_SETTABLE_FLOW_CAP.
    /// @dev Doesn't revert if it doesn't change the storage at all.
    function setFlowCaps(ISiloVault _vault, FlowCapsConfig[] calldata _config) external;
}

/// @dev This interface is inherited by PublicAllocator so that function signatures are checked by the compiler.
/// @dev Consider using the IPublicAllocator interface instead of this one.
interface IPublicAllocatorStaticTyping is IPublicAllocatorBase {
    /// @notice Returns (maximum inflow, maximum outflow) through public allocation of a given market for a given vault.
    function flowCaps(ISiloVault _vault, IERC4626 _market) external view returns (uint128, uint128);
}

/// @title IPublicAllocator
/// @dev Forked with gratitude from Morpho Labs.
/// @author Silo Labs
/// @custom:contact security@silo.finance
/// @dev Use this interface for PublicAllocator to have access to all the functions with the appropriate function
/// signatures.
interface IPublicAllocator is IPublicAllocatorBase {
    /// @notice Returns the maximum inflow and maximum outflow through public allocation of a given market for a given
    /// vault.
    function flowCaps(ISiloVault _vault, IERC4626 _market) external view returns (FlowCaps memory);
}
