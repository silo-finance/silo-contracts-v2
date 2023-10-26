// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {ISiloOracle} from "../../../contracts/interfaces/ISiloOracle.sol";
import {SiloSolvencyLib} from "../../../contracts/lib/SiloSolvencyLib.sol";

abstract contract MockOracleQuote is Test {
    address constant COLLATERAL_ASSET = address(0xc01a);
    address constant DEBT_ASSET = address(0xdeb);

    address constant COLLATERAL_ORACLE = address(0x555555);
    address constant DEBT_ORACLE = address(0x77777);

    function _oraclesQuoteMocks(
        SiloSolvencyLib.LtvData memory _ltvData,
        uint256 _quoteCollateral,
        uint256 _quoteDebt
    ) internal {
        vm.mockCall(
            COLLATERAL_ORACLE,
            abi.encodeWithSelector(
                ISiloOracle.quote.selector,
                _ltvData.borrowerCollateralAssets + _ltvData.borrowerProtectedAssets,
                COLLATERAL_ASSET
            ),
            abi.encode(_quoteCollateral)
        );

        vm.mockCall(
            DEBT_ORACLE,
            abi.encodeWithSelector(ISiloOracle.quote.selector, _ltvData.borrowerDebtAssets, DEBT_ASSET),
            abi.encode(_quoteDebt)
        );
    }
}
