// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {BaseHookReceiver} from "silo-core/contracts/hooks/_common/BaseHookReceiver.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";

/// @notice Hook receiver that only allows protected collateral token transfers for silo0
abstract contract Silo1CollateralOnlyAndDebt is BaseHookReceiver {
    using Hook for uint256;

    error ProtectedTransferNotAllowed();
    error Silo1LTVMustBeZero();

    /// @inheritdoc IHookReceiver
    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput)
        public
        virtual
        override
    {
        (address silo1,) = siloConfig.getSilos();

        if (_silo != silo1) return;

        uint256 protectedTransferAction = Hook.shareTokenTransfer(Hook.PROTECTED_TOKEN);
        require(!_action.matchAction(protectedTransferAction), ProtectedTransferNotAllowed());
    }

    function __Silo1CollateralOnlyAndDebt_init() internal {
        (address silo1,) = siloConfig.getSilos();

        ISiloConfig.ConfigData memory silo1Config = siloConfig.getConfig(silo1);

        require(silo1Config.maxLtv == 0, Silo1LTVMustBeZero());
    }
}
