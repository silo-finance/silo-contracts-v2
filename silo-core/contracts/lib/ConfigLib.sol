// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IHookReceiver} from "../interfaces/IHookReceiver.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";

import {Hook} from "./Hook.sol";

// solhint-disable private-vars-leading-underscore
library ConfigLib {
    using Hook for uint256;

    uint256 internal constant COLLATERAL0_DEBT0 = 0;
    uint256 internal constant COLLATERAL1_DEBT0 = 1;
    uint256 internal constant COLLATERAL0_DEBT1 = 2;
    uint256 internal constant COLLATERAL1_DEBT1 = 3;
    uint256 internal constant COLLATERAL0_NO_DEBT = 4;
    uint256 internal constant COLLATERAL1_NO_DEBT = 5;

    /// @dev result of this method is ordered configs
    /// @param _debtInfo borrower _silo1Conf info
    function orderConfigs(ISiloConfig.DebtInfo memory _debtInfo, bool _callForSilo0)
        internal
        pure
        returns (uint256 order)
    {
        // set helper flag `_debtInfo.debtInThisSilo` at begin, so we can use it everywhere
        if (_debtInfo.debtPresent) _debtInfo.debtInThisSilo = _callForSilo0 == _debtInfo.debtInSilo0;

        if (_debtInfo.debtInSilo0) {
            _debtInfo.debtInThisSilo = _callForSilo0;
            return _debtInfo.sameAsset ? COLLATERAL0_DEBT0 : COLLATERAL1_DEBT0;
        } else {
            _debtInfo.debtInThisSilo = !_callForSilo0;
            return _debtInfo.sameAsset ? COLLATERAL1_DEBT1 : COLLATERAL0_DEBT1;
        }
    }

    function orderConfigsForBorrow(
        ISiloConfig.DebtInfo memory _debtInfo,
        bool _callForSilo0,
        uint256 _action
    )
        internal
        pure
        returns (uint256 order)
    {
        if (_debtInfo.debtPresent) {
            if (_action.matchAction(Hook.SAME_ASSET) != _debtInfo.sameAsset) revert("not possible");
        }

        if (_action.matchAction(Hook.SAME_ASSET)) {
            return _callForSilo0 ? COLLATERAL0_DEBT0 : COLLATERAL1_DEBT1;
        } else if (_action.matchAction(Hook.TWO_ASSETS)) {
            return _callForSilo0 ? COLLATERAL1_DEBT0 : COLLATERAL0_DEBT1;
        } else {
            revert("not supported");
        }
    }

    function orderConfigsForWithdraw(
        ISiloConfig.DebtInfo memory _debtInfo,
        bool _callForSilo0
    )
        internal
        pure
        returns (uint256 order)
    {
        bool withdrawWithoutDebt = isWithdrawWithoutDebt(_debtInfo.debtInSilo0, _debtInfo.sameAsset, _callForSilo0);

        if (!_debtInfo.debtPresent || withdrawWithoutDebt) {
            return _callForSilo0 ? COLLATERAL0_NO_DEBT : COLLATERAL1_NO_DEBT;
        }

        // at this point we know we have debt and borrower wants to withdraw collateral (not a deposit)

        if (_debtInfo.sameAsset) return _callForSilo0 ? COLLATERAL0_DEBT0 : COLLATERAL1_DEBT1;
        else return _callForSilo0 ? COLLATERAL0_DEBT1 : COLLATERAL1_DEBT0;
    }

    function isWithdrawWithoutDebt(bool _debtInSilo0, bool _sameAsset, bool _callForSilo0)
        internal
        pure
        returns (bool yes)
    {
        if (_sameAsset) {
            // if (_debtInSilo0) return !_callForSilo0; // debt,collateral in silo 0
            // else return _callForSilo0; // debt,collateral in silo 1
            return _debtInSilo0 ? !_callForSilo0 : _callForSilo0;
        } else {
            // if (_debtInSilo0) return _callForSilo0; // collateral in 1, debt in 0
            // else return !_callForSilo0; // collateral in 0, debt in 1
            return _debtInSilo0 ? _callForSilo0 : !_callForSilo0;
        }
    }
}
