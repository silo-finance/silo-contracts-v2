// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {SiloLendingLib} from "silo-core/contracts/lib/SiloLendingLib.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

// forge test -vv --mc BorrowPossibleTest
contract BorrowPossibleTest is Test {
    /*
    forge test -vv --mt test_borrowPossible_notPossible_withDebtInOtherSilo_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 20
    function test_borrowPossible_possible_withoutDebt_fuzz(
        bool _singleAsset,
        bool _debtInSilo0,
        bool _debtInThisSilo
    ) public {
        ISiloConfig.DebtInfo memory debtInfo;

        debtInfo.singleAsset = _singleAsset;
        debtInfo.debtInSilo0 = _debtInSilo0;
        debtInfo.debtInThisSilo = _debtInThisSilo;

        debtInfo.debtPresent = false;

        assertTrue(SiloLendingLib.borrowPossible(debtInfo));
    }

    /*
    forge test -vv --mt test_borrowPossible_notPossible_withDebtInOtherSilo_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 10
    function test_borrowPossible_notPossible_withDebtInOtherSilo_fuzz(bool _singleAsset, bool _debtInSilo0) public {
        ISiloConfig.DebtInfo memory debtInfo;

        debtInfo.singleAsset = _singleAsset;
        debtInfo.debtInSilo0 = _debtInSilo0;

        debtInfo.debtPresent = true;
        debtInfo.debtInThisSilo = false;

        assertTrue(!SiloLendingLib.borrowPossible(debtInfo));
    }
}
