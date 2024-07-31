// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {Strings} from "openzeppelin5/utils/Strings.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc MaxBorrowTest
*/
contract MaxBorrowTest is SiloLittleHelper, Test {
    using Strings for uint256;

    ISiloConfig siloConfig;
    address immutable depositor;
    address immutable borrower;

    constructor() {
        depositor = makeAddr("Depositor");
        borrower = makeAddr("Borrower");
    }

    function setUp() public virtual {
        siloConfig = _setUpLocalFixture();
    }

    /*
    forge test -vv --ffi --mt test_Ihor_Case
    */
    function test_Ihor_Case_1() public {
        _Ihor_Case(SAME_ASSET);
    }

    function test_Ihor_Case_2() public {
        _Ihor_Case(TWO_ASSETS);
    }

    // comit: 1d6b67116a6f54f52c66c8440391fc1497989971
    function _Ihor_Case(bool _sameAsset) private {
        _depositCollateral(1e18, borrower, _sameAsset);

        uint256 maxBorrow = silo1.maxBorrow(borrower, _sameAsset);
        emit log_named_uint("maxBorrow before", maxBorrow);
        emit log_named_uint("balance of silo1", token1.balanceOf(address(silo1)));

        if (_sameAsset) {
            assertGt(maxBorrow, 0, "for same asset collateral is liquidity");
        } else {
            assertEq(maxBorrow, 0, "no liquidity");
        }

        _depositForBorrow(1e18, address(2));

        maxBorrow = silo1.maxBorrow(borrower, _sameAsset);
        emit log_named_uint("maxBorrow after", maxBorrow);

        _borrow(maxBorrow, borrower, _sameAsset);
    }
}
