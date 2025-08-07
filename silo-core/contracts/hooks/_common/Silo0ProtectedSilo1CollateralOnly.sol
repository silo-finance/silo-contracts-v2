// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {BaseHookReceiver} from "silo-core/contracts/hooks/_common/BaseHookReceiver.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";

/// @notice Hook receiver that only allows protected token transfers for silo0 and collateral token transfers for silo1
abstract contract Silo0ProtectedSilo1CollateralOnly is BaseHookReceiver {
    using Hook for uint256;

    error CollateralTransferNotAllowed();
    error ProtectedTransferNotAllowed();
    error Silo0LTVNotSet();
    error Silo1LTVMustBeZero();
    error InvalidSilo();

    /// @inheritdoc IHookReceiver
    function afterAction(address _silo, uint256 _action, bytes calldata)
        public
        virtual
        override
    {
        (address silo0, address silo1) = siloConfig.getSilos();

        if (_silo == silo0) { // Silo0: protected token transfers are allowed
            uint256 collateralTokenTransferAction = Hook.shareTokenTransfer(Hook.COLLATERAL_TOKEN);
            require(!_action.matchAction(collateralTokenTransferAction), CollateralTransferNotAllowed());
        } else if (_silo == silo1) { // Silo1: collateral token transfers are allowed
            uint256 protectedTokenTransferAction = Hook.shareTokenTransfer(Hook.PROTECTED_TOKEN);
            require(!_action.matchAction(protectedTokenTransferAction), ProtectedTransferNotAllowed());
        } else {
            revert InvalidSilo();
        }
    }

    /// @notice Initialize the Silo0ProtectedSilo1CollateralOnly hook
    /// @dev Requires silo0 to have a non-zero LTV and silo1 to have a zero LTV
    function __Silo0ProtectedSilo1CollateralOnly_init() internal view {
        (address silo0, address silo1) = siloConfig.getSilos();

        ISiloConfig.ConfigData memory silo0Config = siloConfig.getConfig(silo0);
        require(silo0Config.maxLtv != 0, Silo0LTVNotSet());

        ISiloConfig.ConfigData memory silo1Config = siloConfig.getConfig(silo1);
        require(silo1Config.maxLtv == 0, Silo1LTVMustBeZero());
    }
}
