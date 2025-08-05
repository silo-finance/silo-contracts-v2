// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {BaseHookReceiver} from "silo-core/contracts/hooks/_common/BaseHookReceiver.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";

/// @notice Hook receiver that only allows protected collateral token transfers for silo0
abstract contract Silo0ProtectedCollateralOnly is BaseHookReceiver {
    using Hook for uint256;

    error CollateralTokenTransferNotAllowed();
    error Silo0LTVNotSet();

    /// @inheritdoc IHookReceiver
    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput)
        public
        virtual
        override
    {
        (address silo0,) = siloConfig.getSilos();

        if (_silo != silo0) return;

        uint256 collateralTokenTransferAction = Hook.shareTokenTransfer(Hook.COLLATERAL_TOKEN);
        require(!_action.matchAction(collateralTokenTransferAction), CollateralTokenTransferNotAllowed());
    }

    function __Silo0ProtectedCollateralOnly_init() internal {
        (address silo0,) = siloConfig.getSilos();

        ISiloConfig.ConfigData memory silo0Config = siloConfig.getConfig(silo0);

        require(silo0Config.maxLtv != 0, Silo0LTVNotSet());
    }
}
