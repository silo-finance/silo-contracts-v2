// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {GaugeHookReceiver} from "silo-core/contracts/hooks/gauge/GaugeHookReceiver.sol";
import {PartialLiquidation} from "silo-core/contracts/hooks/liquidation/PartialLiquidation.sol";
import {PartialLiquidationByDefaulting} from "silo-core/contracts/hooks/liquidation/PartialLiquidationByDefaulting.sol";
import {BaseHookReceiver} from "silo-core/contracts/hooks/_common/BaseHookReceiver.sol";

contract SiloHookV2 is GaugeHookReceiver, PartialLiquidation, PartialLiquidationByDefaulting {
    /// @inheritdoc IHookReceiver
    function initialize(ISiloConfig _config, bytes calldata _data)
        public
        initializer
        virtual
    {
        (address owner, uint256 keeperFee) = abi.decode(_data, (address, uint256));

        BaseHookReceiver.__BaseHookReceiver_init(_config);
        GaugeHookReceiver.__GaugeHookReceiver_init(owner);
        PartialLiquidationByDefaulting.__PartialLiquidationByDefaulting_init(keeperFee);
    }

    /// @inheritdoc IHookReceiver
    function beforeAction(address, uint256, bytes calldata)
        public
        virtual
        onlySilo()
        override
    {
        // Do not expect any actions.
        revert RequestNotSupported();
    }

    /// @inheritdoc IHookReceiver
    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput)
        public
        virtual
        onlySiloOrShareToken()
        override(GaugeHookReceiver, IHookReceiver)
    {
        GaugeHookReceiver.afterAction(_silo, _action, _inputAndOutput);
    }

    function _fetchConfigs(
        ISiloConfig _siloConfigCached,
        address _collateralAsset,
        address _debtAsset,
        address _borrower
    )
        internal
        override(PartialLiquidation, PartialLiquidationByDefaulting)
        virtual
        returns (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        )
    {
        return PartialLiquidationByDefaulting._fetchConfigs(
            _siloConfigCached, _collateralAsset, _debtAsset, _borrower
        );
    }

    function _callShareTokenForwardTransferNoChecks(
        address _silo,
        address _borrower,
        address _receiver,
        uint256 _withdrawAssets,
        address _shareToken,
        ISilo.AssetType _assetType
    ) internal override(PartialLiquidation, PartialLiquidationByDefaulting) virtual returns (uint256 shares) {
        return PartialLiquidationByDefaulting._callShareTokenForwardTransferNoChecks(
            _silo,
            _borrower,
            _receiver,
            _withdrawAssets,
            _shareToken,
            _assetType
        );
    }
}
