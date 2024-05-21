// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IHookReceiver} from "../interfaces/IHookReceiver.sol";
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
}
