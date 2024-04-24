// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IHookReceiver} from "../utils/hook-receivers/interfaces/IHookReceiver.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";

import {Hook} from "./Hook.sol";

// solhint-disable private-vars-leading-underscore
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
        pure
        returns (uint256 order)
    {
        if (!_debtInfo.debtPresent) {
            if (_hook & (Hook.BORROW | Hook.SAME_ASSET) == Hook.BORROW | Hook.SAME_ASSET) {
                return _callForSilo0 ? SILO0_SILO0 : SILO1_SILO1;
            } else if (_hook & (Hook.BORROW | Hook.TWO_ASSETS) == Hook.BORROW | Hook.SAME_ASSET) {
                return _callForSilo0 ? SILO1_SILO0 : SILO0_SILO1;
            } else {
                return _callForSilo0 ? SILO0_SILO1 : SILO1_SILO0;
            }
        } else if (_hook & Hook.WITHDRAW == Hook.WITHDRAW) {
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
