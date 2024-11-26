// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {IMetaMorpho} from "./IMetaMorpho.sol";

    /// @dev Max settable flow cap, such that caps can always be stored on 128 bits.
    /// @dev The actual max possible flow cap is type(uint128).max-1.
    /// @dev Equals to 170141183460469231731687303715884105727;
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
    function admin(IMetaMorpho vault) external view returns (address);

    /// @notice The current ETH fee for a given vault.
    function fee(IMetaMorpho vault) external view returns (uint256);

    /// @notice The accrued ETH fee for a given vault.
    function accruedFee(IMetaMorpho vault) external view returns (uint256);

    /// @notice Reallocates from a list of markets to one market.
    /// @param vault The MetaMorpho vault to reallocate.
    /// @param withdrawals The markets to withdraw from,and the amounts to withdraw.
    /// @param supplyMarket The market receiving total withdrawn to.
    /// @dev Will call MetaMorpho's `reallocate`.
    /// @dev Checks that the flow caps are respected.
    /// @dev Will revert when `withdrawals` contains a duplicate or is not sorted.
    /// @dev Will revert if `withdrawals` contains the supply market.
    /// @dev Will revert if a withdrawal amount is larger than available liquidity.
    function reallocateTo(IMetaMorpho vault, Withdrawal[] calldata withdrawals, IERC4626 supplyMarket)
        external
        payable;

    /// @notice Sets the admin for a given vault.
    function setAdmin(IMetaMorpho vault, address newAdmin) external;

    /// @notice Sets the fee for a given vault.
    function setFee(IMetaMorpho vault, uint256 newFee) external;

    /// @notice Transfers the current balance to `feeRecipient` for a given vault.
    function transferFee(IMetaMorpho vault, address payable feeRecipient) external;

    /// @notice Sets the maximum inflow and outflow through public allocation for some markets for a given vault.
    /// @dev Max allowed inflow/outflow is MAX_SETTABLE_FLOW_CAP.
    /// @dev Doesn't revert if it doesn't change the storage at all.
    function setFlowCaps(IMetaMorpho vault, FlowCapsConfig[] calldata config) external;
}

/// @dev This interface is inherited by PublicAllocator so that function signatures are checked by the compiler.
/// @dev Consider using the IPublicAllocator interface instead of this one.
interface IPublicAllocatorStaticTyping is IPublicAllocatorBase {
    /// @notice Returns (maximum inflow, maximum outflow) through public allocation of a given market for a given vault.
    function flowCaps(IMetaMorpho vault, IERC4626 market) external view returns (uint128, uint128);
}

/// @title IPublicAllocator
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @dev Use this interface for PublicAllocator to have access to all the functions with the appropriate function
/// signatures.
interface IPublicAllocator is IPublicAllocatorBase {
    /// @notice Returns the maximum inflow and maximum outflow through public allocation of a given market for a given
    /// vault.
    function flowCaps(IMetaMorpho vault, IERC4626 market) external view returns (FlowCaps memory);
}
