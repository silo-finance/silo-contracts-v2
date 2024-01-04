// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {SiloLendingLib} from "silo-core/contracts/lib/SiloLendingLib.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import "../../_mocks/TokenMock.sol";

// forge test -vv --mc BorrowPossibleTest
contract BorrowPossibleTest is Test {
    /*
    forge test -vv --mt test_borrowPossible_borrowable_zeros
    */
    function test_borrowPossible_borrowable_zeros() public {
        TokenMock protectedShareToken = new TokenMock(address(0x111));
        TokenMock collateralShareToken = new TokenMock(address(0x222));
        address borrower = address(0x333);

        protectedShareToken.balanceOfMock(borrower, 0);
        collateralShareToken.balanceOfMock(borrower, 0);

        bool possible = SiloLendingLib.borrowPossible(protectedShareToken.ADDRESS(), collateralShareToken.ADDRESS(), borrower);

        assertTrue(possible, "borrow possible when borrowPossible=true and no collateral in this token");
    }

    /*
    forge test -vv --mt test_borrowPossible_borrowable_notPossibleWithCollateral
    */
    function test_borrowPossible_borrowable_notPossibleWithCollateral() public {
        TokenMock protectedShareToken = new TokenMock(address(0x111));
        TokenMock collateralShareToken = new TokenMock(address(0x222));
        address borrower = address(0x333);

        protectedShareToken.balanceOfMock(borrower, 0);
        collateralShareToken.balanceOfMock(borrower, 2);

        bool possible = SiloLendingLib.borrowPossible(protectedShareToken.ADDRESS(), collateralShareToken.ADDRESS(), borrower);

        assertFalse(possible, "borrow NOT possible when borrowPossible=true and no collateral in this token");
    }

    /*
    forge test -vv --mt test_borrowPossible_borrowable_notPossibleWithProtected
    */
    function test_borrowPossible_borrowable_notPossibleWithProtected() public {
        TokenMock protectedShareToken = new TokenMock(address(0x111));
        TokenMock collateralShareToken = new TokenMock(address(0x222));
        address borrower = address(0x333);

        protectedShareToken.balanceOfMock(borrower, 1);

        bool possible = SiloLendingLib.borrowPossible(protectedShareToken.ADDRESS(), collateralShareToken.ADDRESS(), borrower);

        assertFalse(possible, "borrow NOT possible when borrowPossible=true and no collateral in this token");
    }
}
