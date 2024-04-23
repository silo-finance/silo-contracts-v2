// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";

import {IHookReceiver} from "../utils/hook-receivers/interfaces/IHookReceiver.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";

import {Hook} from "./Hook.sol";

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
                console.log("[no debt] BORROW SAME_ASSET");
                return _callForSilo0 ? SILO0_SILO0 : SILO1_SILO1;
            } else if (_hook & (Hook.BORROW | Hook.TWO_ASSETS) != 0) {
                console.log("[no debt] BORROW TWO_ASSETS");
                return _callForSilo0 ? SILO1_SILO0 : SILO0_SILO1;
            } else {
               return _callForSilo0 ? SILO0_SILO1 : SILO1_SILO0;
                console.log("[no debt]");
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

        console.log("debt is present");

        if (_debtInfo.debtInSilo0) {
            console.log("[debt present] debtInSilo0 - yes");
            _debtInfo.debtInThisSilo = _callForSilo0;
            return _debtInfo.sameAsset ? SILO0_SILO0 : SILO1_SILO0;
        } else {
            console.log("[debt present] debtInSilo0 - no");
            _debtInfo.debtInThisSilo = !_callForSilo0;
            return _debtInfo.sameAsset ? SILO1_SILO1 : SILO0_SILO1;
        }
    }
}
