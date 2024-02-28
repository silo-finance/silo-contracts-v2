// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {SiloERC4626Lib} from "silo-core/contracts/lib/SiloERC4626Lib.sol";
import {TokenMock} from "../../_mocks/TokenMock.sol";

contract SiloERC4626LibImpl {
    function depositPossible(address _debtShareToken, address _depositor) external view returns (bool) {
        return SiloERC4626Lib.depositPossible(_debtShareToken, _depositor);
    }
}

/*
forge test -vv --mc DepositPossibleTest
*/
contract DepositPossibleTest is Test {
    SiloERC4626LibImpl private immutable _impl;

    constructor() {
        _impl = new SiloERC4626LibImpl();
    }

    // forge test -vv --mt test_depositPossible_throwOnZeros
    function test_depositPossible_throwOnZeros() public {
        address debtShareToken;
        address depositor;

        vm.expectRevert();
        _impl.depositPossible(debtShareToken, depositor);
    }

    function test_depositPossible_throwOnWrongTokenAddress() public {
        address debtShareToken = address(1);
        address depositor;

        vm.expectRevert();
        _impl.depositPossible(debtShareToken, depositor);
    }

    function test_depositPossible_falseWhenBalance() public {
        TokenMock debtShareToken = new TokenMock(address(0));
        address depositor;

        debtShareToken.balanceOfMock(depositor, 1);
        assertFalse(SiloERC4626Lib.depositPossible(debtShareToken.ADDRESS(), depositor), "false when balance");
    }

    function test_depositPossible_trueWhenNoBalance() public {
        TokenMock debtShareToken = new TokenMock(address(0));
        address depositor = address(2);

        debtShareToken.balanceOfMock(depositor, 0);
        assertTrue(SiloERC4626Lib.depositPossible(debtShareToken.ADDRESS(), depositor), "true when NO balance");
    }
}
