// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IHookReceiver} from "../utils/hook-receivers/interfaces/IHookReceiver.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";

import {Hook} from "./Hook.sol";


library ConfigLib {
    /// @dev result of this method is ordered configs
    /// @param _silo0Conf ConfigData for SILO0
    /// @param _silo1Conf ConfigData for SILO1
    /// @param _debtInfo borrower _silo1Conf info
    /// @param _hook this is action for which we pulling configs
    function orderConfigs(
        ISiloConfig.ConfigData memory _silo0Conf, // by default silo0
        ISiloConfig.ConfigData memory _silo1Conf, // by default silo1
        ISiloConfig.DebtInfo memory _debtInfo,
        bool _callForSilo0,
        uint256 _hook
    )
        internal
        pure
    {
        if (!_debtInfo.debtPresent) {
            if (_hook & Hook.BORROW & Hook.SAME_ASSET != 0) {
                (_silo0Conf, _silo1Conf) = _callForSilo0 ? (_silo0Conf, _silo0Conf) : (_silo1Conf, _silo1Conf);
                return;
            } else if (_hook & Hook.BORROW & Hook.TWO_ASSETS != 0) {
                (_silo0Conf, _silo1Conf) = _callForSilo0 ? (_silo1Conf, _silo0Conf) : (_silo0Conf, _silo1Conf);
                return;
            } else {
                (_silo0Conf, _silo1Conf) = _callForSilo0 ? (_silo0Conf, _silo1Conf) : (_silo1Conf, _silo0Conf);
                return;
            }
        } else if (_hook & Hook.WITHDRAW != 0) {
            _debtInfo.debtInThisSilo = _callForSilo0 == _debtInfo.debtInSilo0;

            if (_debtInfo.sameAsset) {
                if (_debtInfo.debtInSilo0) {
                    (_silo0Conf, _silo1Conf) = _callForSilo0
                        ? (_silo0Conf, _silo0Conf)
                        : (_silo1Conf, _silo0Conf); // only deposit
                    return;
                } else {
                    (_silo0Conf, _silo1Conf) = _callForSilo0
                        ? (_silo0Conf, _silo1Conf) // only deposit
                        : (_silo1Conf, _silo1Conf);
                    return;
                }
            } else {
                if (_debtInfo.debtInSilo0) {
                    (_silo0Conf, _silo1Conf) = _callForSilo0
                        ? (_silo0Conf, _silo1Conf)
                        : (_silo1Conf, _silo0Conf); // only deposit
                    return;
                } else {
                    (_silo0Conf, _silo1Conf) = _callForSilo0
                        ? (_silo0Conf, _silo1Conf) // only deposit
                        : (_silo1Conf, _silo0Conf);
                    return;
                }
            }
        }

        if (_debtInfo.debtInSilo0) {
            _debtInfo.debtInThisSilo = _callForSilo0;

            if (_debtInfo.sameAsset) {
                _silo1Conf = _silo0Conf;
            } else {
                (_silo0Conf, _silo1Conf) = (_silo1Conf, _silo0Conf);
            }
        } else {
            _debtInfo.debtInThisSilo = !_callForSilo0;

            if (_debtInfo.sameAsset) {
                _silo0Conf = _silo1Conf;
            }
        }
    }
}
