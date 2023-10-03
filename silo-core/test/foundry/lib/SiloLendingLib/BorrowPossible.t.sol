// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {SiloLendingLib} from "silo-core/contracts/lib/SiloLendingLib.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import "../../_mocks/TokenMock.sol";

// forge test -vv --mc BorrowPossibleTest
contract BorrowPossibleTest is Test {
    uint256 constant BASIS_POINTS = 1e4;

    /*
    forge test -vv --mt test_borrowPossible_notBorrowable_zeros
    */
    function test_borrowPossible_notBorrowable_zeros() public {
        address protectedShareToken;
        address collateralShareToken;
        bool borrowable;
        address borrower = address(0x333);

        assertFalse(
            SiloLendingLib.borrowPossible(protectedShareToken, collateralShareToken, borrowable, borrower),
            "borrow NOT possible when borrowPossible=false"
        );
    }

    /*
    forge test -vv --mt test_borrowPossible_borrowable_zeros
    */
    function test_borrowPossible_borrowable_zeros() public {
        TokenMock protectedShareToken = new TokenMock(vm, address(0x111));
        TokenMock collateralShareToken = new TokenMock(vm, address(0x222));
        bool borrowable = true;
        address borrower = address(0x333);

        protectedShareToken.balanceOfMock(borrower, 0);
        collateralShareToken.balanceOfMock(borrower, 0);

        bool possible = SiloLendingLib.borrowPossible(protectedShareToken.ADDRESS(), collateralShareToken.ADDRESS(), borrowable, borrower);

        assertTrue(possible, "borrow possible when borrowPossible=true and no collateral in this token");
    }

    /*
    forge test -vv --mt test_borrowPossible_borrowable_notPossibleWithCollateral
    */
    function test_borrowPossible_borrowable_notPossibleWithCollateral() public {
        TokenMock protectedShareToken = new TokenMock(vm, address(0x111));
        TokenMock collateralShareToken = new TokenMock(vm, address(0x222));
        bool borrowable = true;
        address borrower = address(0x333);

        protectedShareToken.balanceOfMock(borrower, 0);
        collateralShareToken.balanceOfMock(borrower, 2);

        uint256 gasStart = gasleft();
        bool possible = SiloLendingLib.borrowPossible(protectedShareToken.ADDRESS(), collateralShareToken.ADDRESS(), borrowable, borrower);
        uint256 gasEnd = gasleft();

        assertEq(gasStart - gasEnd, 5758, "optimise borrowPossible ");
        assertFalse(possible, "borrow NOT possible when borrowPossible=true and no collateral in this token");
    }

    /*
    forge test -vv --mt test_borrowPossible_borrowable_notPossibleWithProtected
    */
    function test_borrowPossible_borrowable_notPossibleWithProtected() public {
        TokenMock protectedShareToken = new TokenMock(vm, address(0x111));
        TokenMock collateralShareToken = new TokenMock(vm, address(0x222));
        bool borrowable = true;
        address borrower = address(0x333);

        protectedShareToken.balanceOfMock(borrower, 1);

        uint256 gasStart = gasleft();
        bool possible = SiloLendingLib.borrowPossible(protectedShareToken.ADDRESS(), collateralShareToken.ADDRESS(), borrowable, borrower);
        uint256 gasEnd = gasleft();

        assertEq(gasStart - gasEnd, 5385, "optimise borrowPossible");
        assertFalse(possible, "borrow NOT possible when borrowPossible=true and no collateral in this token");
    }
}
