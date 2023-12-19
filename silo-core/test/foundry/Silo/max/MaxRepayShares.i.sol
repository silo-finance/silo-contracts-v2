// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc MaxRepayTest
*/
contract MaxRepaySharesTest is SiloLittleHelper, Test {
    uint256 internal constant _REAL_ASSETS_LIMIT = type(uint128).max;
    
    ISiloConfig siloConfig;
    address immutable depositor;
    address immutable borrower;

    constructor() {
        depositor = makeAddr("Depositor");
        borrower = makeAddr("Borrower");
    }

    function setUp() public {
        siloConfig = _setUpLocalFixture(SiloConfigsNames.LOCAL_NO_ORACLE_NO_LTV_SILO);
    }

    /*
    forge test -vv --ffi --mt test_maxRepayShares_noDebt
    */
    function test_maxRepayShares_noDebt() public {
        uint256 maxRepayShares = silo1.maxRepayShares(borrower);
        assertEq(maxRepayShares, 0, "no debt - nothing to repay");

        _depositForBorrow(11e18, borrower);

        _assertBorrowerHadNoDebt();
    }

    /*
    forge test -vv --ffi --mt test_maxRepayShares_withDebt_fuzz
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_maxRepayShares_withDebt_fuzz(uint128 _collateral) public {
        uint256 toBorrow = _collateral / 3;
        _createDebt(_collateral, toBorrow);

        uint256 maxRepayShares = silo1.maxRepayShares(borrower);
        assertEq(maxRepayShares, toBorrow, "max repay is what was borrower if no interest");

        _repayShares(maxRepayShares, maxRepayShares, borrower);
        _assertBorrowerHadNoDebt();
    }

    /*
    forge test -vv --ffi --mt test_maxRepayShares_withInterest_fuzz
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_maxRepayShares_withInterest_fuzz(uint128 _collateral) public {
        uint256 toBorrow = _collateral / 3;
        uint256 shares = _createDebt(_collateral, toBorrow);

        vm.warp(block.timestamp + 356 days);

        uint256 maxRepayShares = silo1.maxRepayShares(borrower);
        assertEq(maxRepayShares, shares, "shares are always the same");

        token1.setOnDemand(true);
        _repayShares(1, maxRepayShares, borrower);
        _assertBorrowerHadNoDebt();
    }

    function _createDebt(uint256 _collateral, uint256 _toBorrow) internal returns (uint256 shares) {
        vm.assume(_collateral > 0);
        vm.assume(_toBorrow > 0);

        _depositForBorrow(_collateral, depositor);
        _deposit(_collateral, borrower);
        return _borrow(_toBorrow, borrower);
    }

    function _assertBorrowerHadNoDebt() internal {
        (,, address debtShareToken) = silo1.config().getShareTokens(address(silo1));

        assertEq(silo1.maxRepayShares(borrower), 0, "expect maxRepayShares to be 0");
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0, "expect debtShareToken balanace to be 0");
    }
}
