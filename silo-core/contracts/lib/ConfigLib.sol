// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IHookReceiver} from "../utils/hook-receivers/interfaces/IHookReceiver.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";

import {Hook} from "./Hook.sol";

// solhint-disable private-vars-leading-underscore
library ConfigLib {
    using Hook for uint256;

    uint256 internal constant SILO0_SILO0 = 0;
    uint256 internal constant SILO1_SILO0 = 1;
    uint256 internal constant SILO0_SILO1 = 2;
    uint256 internal constant SILO1_SILO1 = 3;

    /// @dev result of this method is ordered configs
    /// @param _debtInfo borrower _silo1Conf info
    /// @param _action this is action for which we pulling configs
    function orderConfigs(
        ISiloConfig.DebtInfo memory _debtInfo,
        bool _callForSilo0,
        uint256 _action
    )
        internal
        pure
        returns (uint256 order)
    {
        if (!_debtInfo.debtPresent) {
            if (_action & (Hook.BORROW | Hook.SAME_ASSET) == Hook.BORROW | Hook.SAME_ASSET) {
                return _callForSilo0 ? SILO0_SILO0 : SILO1_SILO1;
            } else if (_action & (Hook.BORROW | Hook.TWO_ASSETS) == Hook.BORROW | Hook.TWO_ASSETS) {
                return _callForSilo0 ? SILO1_SILO0 : SILO0_SILO1;
            } else {
                return _callForSilo0 ? SILO0_SILO1 : SILO1_SILO0;
            }
        } else if (_action.matchAction(Hook.WITHDRAW)) {
            _debtInfo.debtInThisSilo = _callForSilo0 == _debtInfo.debtInSilo0;

            if (_debtInfo.sameAsset) {
                if (_debtInfo.debtInSilo0) {
                    return _callForSilo0 ? SILO0_SILO0 : SILO1_SILO0 /* only deposit */;
                } else {
                    return _callForSilo0 ? SILO0_SILO1 /* only deposit */ : SILO1_SILO1;
                }
            } else {
                if (_debtInfo.debtInSilo0) {
                    return _callForSilo0 ? SILO0_SILO1 : SILO1_SILO0 /* only deposit */;
                } else {
                    return _callForSilo0 ? SILO0_SILO1 /* only deposit */ : SILO1_SILO0;
                }
            }
        }

        if (_debtInfo.debtInSilo0) {
            _debtInfo.debtInThisSilo = _callForSilo0;
            return _debtInfo.sameAsset ? SILO0_SILO0 : SILO1_SILO0;
        } else {
            _debtInfo.debtInThisSilo = !_callForSilo0;
            return _debtInfo.sameAsset ? SILO1_SILO1 : SILO0_SILO1;
        }
    }

    function pullConfigs(ISiloConfig _siloConfig, address _silo, address _borrower, uint256 _action)
        internal
        view
        returns (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig,
            ISiloConfig.DebtInfo memory debtInfo
        )
    {
        bytes memory cfg;
        (cfg, debtInfo) = _siloConfig.getConfigs(_silo, _borrower, _action);

        (collateralConfig, debtConfig) = _decodeConfigs(cfg, debtInfo);
    }

    function accrueInterestAndPullConfigs(ISiloConfig _siloConfig, address _borrower, uint256 _action)
        internal
        returns (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig,
            ISiloConfig.DebtInfo memory debtInfo
        )
    {
        bytes memory cfg;
        (cfg, debtInfo) = _siloConfig.accrueInterestAndGetConfigs(address(this), _borrower, _action);

        (collateralConfig, debtConfig) = _decodeConfigs(cfg, debtInfo);
    }

    function _decodeConfigs(bytes memory cfg, ISiloConfig.DebtInfo memory debtInfo)
        private
        pure
        returns (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        )
    {
        if (debtInfo.sameAsset) {
            (collateralConfig) = abi.decode(cfg, (ISiloConfig.ConfigData));
            debtConfig = collateralConfig;
        } else {
            (collateralConfig, debtConfig) = abi.decode(cfg, (ISiloConfig.ConfigData, ISiloConfig.ConfigData));
        }
    }
}
