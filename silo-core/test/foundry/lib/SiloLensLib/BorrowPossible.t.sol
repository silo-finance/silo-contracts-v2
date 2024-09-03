// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";

import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";


/*
forge test --ffi -vv --mc BorrowPossibleTest
*/
contract BorrowPossibleTest is Test, SiloLittleHelper {
    using SiloLensLib for ISilo;

    ISiloConfig siloConfig;

    function setUp() public {
        siloConfig = _setUpLocalFixture();
    }

    /*
    forge test --ffi -vv --mt test_borrowPossible_whenNoDebt
    */
    function test_borrowPossible_whenNoDebt() public {
        assertTrue(silo0.borrowPossible(address(0)));
        assertTrue(silo1.borrowPossible(address(0)));
    }

    function test_borrowPossible_withDeposit() public {
        address depositor = makeAddr("depositor");

        _deposit(1, depositor);

        assertTrue(silo0.borrowPossible(depositor));
        assertTrue(silo1.borrowPossible(depositor));
    }

    function test_borrowPossible_with2Deposits() public {
        address depositor = makeAddr("depositor");

        _deposit(1, depositor);
        _depositForBorrow(10, depositor);

        assertTrue(silo0.borrowPossible(depositor));
        assertTrue(silo1.borrowPossible(depositor));
    }

    function test_borrowPossible_withDebt() public {
        address depositor = makeAddr("depositor");

        _deposit(10, depositor);
        _depositForBorrow(10, depositor);
        _borrow(1, depositor);

        assertTrue(!silo0.borrowPossible(depositor));
        assertTrue(silo1.borrowPossible(depositor));
    }
}
