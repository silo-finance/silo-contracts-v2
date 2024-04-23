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
    uint256 internal constant SILO0_SILO0 = 0;
    uint256 internal constant SILO1_SILO0 = 1;
    uint256 internal constant SILO0_SILO1 = 2;
    uint256 internal constant SILO1_SILO1 = 3;

    /// @dev result of this method is ordered configs
    /// @param _debtInfo borrower _silo1Conf info
    /// @param _hook this is action for which we pulling configs
    function orderConfigs(
        ISiloConfig.DebtInfo memory _debtInfo,
        bool _callForSilo0,
        uint256 _hook
    )
        internal
        view
        returns (uint256 order)
    {
        if (!_debtInfo.debtPresent) {
            if (_hook & (Hook.BORROW | Hook.SAME_ASSET) != 0) {
                return _callForSilo0 ? SILO0_SILO0 : SILO1_SILO1;
            } else if (_hook & (Hook.BORROW | Hook.TWO_ASSETS) != 0) {
                return _callForSilo0 ? SILO1_SILO0 : SILO0_SILO1;
            } else {
               return _callForSilo0 ? SILO0_SILO1 : SILO1_SILO0;
            }
        } else if (_hook & Hook.WITHDRAW != 0) {
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
}
