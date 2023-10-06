// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "silo-core/contracts/lib/SiloStdLib.sol";

import {TokenMock} from "../../_mocks/TokenMock.sol";


// forge test -vv --mc GetSharesAndTotalSupplyTest
contract GetSharesAndTotalSupplyTest is Test {
    TokenMock immutable SHARE_TOKEN;

    constructor () {
        SHARE_TOKEN = new TokenMock(vm, address(0));
    }

    /*
    forge test -vv --mt test_getSharesAndTotalSupply_zeros
    */
    function test_getSharesAndTotalSupply_zeros() public {
        address shareToken = SHARE_TOKEN.ADDRESS();
        address owner;

        SHARE_TOKEN.balanceOfMock(owner, 0);
        SHARE_TOKEN.totalSupplyMock(0);
        (uint256 shares, uint256 totalSupply) = SiloStdLib.getSharesAndTotalSupply(shareToken, owner);
        assertEq(shares, 0, "zero shares");
        assertEq(totalSupply, 0, "zero totalSupply");
    }

    /*
    forge test -vv --mt test_getSharesAndTotalSupply_pass
    */
    function test_getSharesAndTotalSupply_pass() public {
        address shareToken = SHARE_TOKEN.ADDRESS();
        address owner = address(2);

        SHARE_TOKEN.balanceOfMock(owner, 111);
        SHARE_TOKEN.totalSupplyMock(222);
        (uint256 shares, uint256 totalSupply) = SiloStdLib.getSharesAndTotalSupply(shareToken, owner);
        assertEq(shares, 111, "shares");
        assertEq(totalSupply, 222, "totalSupply");
    }
}
