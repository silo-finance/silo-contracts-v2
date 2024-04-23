// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";

import {IHookReceiver} from "../utils/hook-receivers/interfaces/IHookReceiver.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";

import {Hook} from "./Hook.sol";

// TODO problem with this lib is that it take 4K gas to order them
// solutions:
// - keep it in SiloConfig so we do not create copies of ConfigData
// - operate on uint instead of ConfigData, and then pull final config in right order
// - operate on methods as return data
// - if we can move debtInfo to Silo0 (or keep it simply in Silo),
//   then this is enough to pre-order and then we just need to pull config
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
        view
        returns (ISiloConfig.ConfigData memory collateral, ISiloConfig.ConfigData memory debt)
    {
        if (!_debtInfo.debtPresent) {
            if (_hook & Hook.BORROW & Hook.SAME_ASSET != 0) {
                return _callForSilo0 ? (_silo0Conf, _silo0Conf) : (_silo1Conf, _silo1Conf);
            } else if (_hook & Hook.BORROW & Hook.TWO_ASSETS != 0) {
                return _callForSilo0 ? (_silo1Conf, _silo0Conf) : (_silo0Conf, _silo1Conf);
            } else {
               return _callForSilo0 ? (_silo0Conf, _silo1Conf) : (_silo1Conf, _silo0Conf);
            }
        } else if (_hook & Hook.WITHDRAW != 0) {
            _debtInfo.debtInThisSilo = _callForSilo0 == _debtInfo.debtInSilo0;

            if (_debtInfo.sameAsset) {
                if (_debtInfo.debtInSilo0) {
                    return _callForSilo0
                        ? (_silo0Conf, _silo0Conf)
                        : (_silo1Conf, _silo0Conf); // only deposit
                } else {
                    return _callForSilo0
                        ? (_silo0Conf, _silo1Conf) // only deposit
                        : (_silo1Conf, _silo1Conf);
                }
            } else {
                if (_debtInfo.debtInSilo0) {
                    return _callForSilo0
                        ? (_silo0Conf, _silo1Conf)
                        : (_silo1Conf, _silo0Conf); // only deposit
                } else {
                    return _callForSilo0
                        ? (_silo0Conf, _silo1Conf) // only deposit
                        : (_silo1Conf, _silo0Conf);
                }
            }
        }

        if (_debtInfo.debtInSilo0) {
            _debtInfo.debtInThisSilo = _callForSilo0;

            if (_debtInfo.sameAsset) {
                debt = _silo0Conf;
            } else {
                return (_silo1Conf, _silo0Conf);
            }
        } else {
            _debtInfo.debtInThisSilo = !_callForSilo0;

            if (_debtInfo.sameAsset) {
                collateral = _silo1Conf;
            }
        }
    }
}
