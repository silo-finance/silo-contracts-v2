// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IComplianceResolver} from "silo-core/contracts/interfaces/compliance/IComplianceResolver.sol";

/// @title ICompliantHook
/// @notice Interface for the compliant hook.
/// @dev Extension for the Silo Hooks in case we need to check compliance.
interface ICompliantHook {
    /// @notice Set the compliance resolver.
    /// @param _resolver The compliance resolver to set.
    function setComplianceResolver(IComplianceResolver _resolver) external;

    /// @notice Enable the compliance check for the action.
    /// @param _actions The action to enable the compliance check for.
    /// @dev This action configure silo to send notifications to the hook.
    /// This fn is protected and allowed only for the resolver.
    function enableComplianceCheck(uint24[] memory _actions) external;

    /// @notice Get the compliance resolver.
    /// @return resolver The compliance resolver.
    function getComplianceResolver() external view returns (IComplianceResolver resolver);
}
