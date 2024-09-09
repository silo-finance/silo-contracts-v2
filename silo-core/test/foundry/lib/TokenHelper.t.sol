// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "silo-core/contracts/lib/TokenHelper.sol";

contract MockTokenNoMetadata { }

contract MockTokenWithMetadata {
    string public symbol;
    uint8 public decimals;

    constructor(string memory _symbol, uint8 _decimals) {
        symbol = _symbol;
        decimals = _decimals;
    }
}

// forge test -vv --mc TokenHelperTest
contract TokenHelperTest is Test {
    function setUp() public {
    }

    function test_NoContract() public {
        address empty = address(1);

        vm.expectRevert(TokenHelper.TokenIsNotAContract.selector);
        TokenHelper.assertAndGetDecimals(empty);

        vm.expectRevert(TokenHelper.TokenIsNotAContract.selector);
        TokenHelper.symbol(empty);
    }

    function test_NoMetadata() public {
        address token = address(new MockTokenNoMetadata());

        uint256 decimals = TokenHelper.assertAndGetDecimals(token);
        assertEq(decimals, 0);

        string memory symbol = TokenHelper.symbol(token);
        assertEq(symbol, "?");
    }

    function test_Metadata() public {
        string memory symbol = "ABC";
        uint8 decimals = 123;
        address token = address(new MockTokenWithMetadata(symbol, decimals));

        assertEq(TokenHelper.symbol(token), symbol);
        assertEq(TokenHelper.assertAndGetDecimals(token), decimals);
    }

    function test_removeZeros() public {
        assertEq(TokenHelper.removeZeros(""), "");
        assertEq(TokenHelper.removeZeros("0"), "0");
        assertEq(TokenHelper.removeZeros(abi.encode(0x20)), " ");
        assertEq(TokenHelper.removeZeros(abi.encode(0x20414243000000)), " ABC");
    }
}
