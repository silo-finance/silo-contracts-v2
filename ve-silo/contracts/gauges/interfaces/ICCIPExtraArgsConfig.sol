// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

interface ICCIPExtraArgsConfig {
    /// @notice Write info the log whenever new configuration is set
    /// @param extraArgs New extra args
    event ExtraArgsUpdated(bytes extraArgs);

    /// @notice Sets `extraArgs` for an `EVM2AnyMessage`.
    /// @param _extraArgs Extra args for the CCIP `EVM2AnyMessage`
    /// @dev The purpose of extraArgs is to allow compatibility with future CCIP upgrades.
    /// To get this benefit, make sure that extraArgs is mutable in production deployments.
    /// This allows you to build it off-chain and pass it in a call to a function
    /// or store it in a variable that you can update on-demand.
    function setExtraArgs(bytes calldata _extraArgs) external;

    /// @notice Returns configured extra args for an `EVM2AnyMessage`
    function extraArgs() external view returns (bytes memory configuredExtraArgs);
}
