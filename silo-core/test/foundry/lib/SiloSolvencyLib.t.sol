// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../../contracts/lib/SiloSolvencyLib.sol";


// forge test -vv --mc SiloSolvencyLibTest
contract SiloSolvencyLibTest is Test {
    /*
    forge test -vv --mt test_SiloSolvencyLib_getPositionValues_noOracle
    */
    function test_SiloSolvencyLib_getPositionValues_noOracle() public {
        ISiloOracle noOracle;
        uint256 protectedAssets = 10;
        uint256 collateralAssets = 20;
        uint256 debtAssets = 3;

        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.LtvData(
            noOracle, noOracle, protectedAssets, collateralAssets, debtAssets
        );

        address any = address(1);

        (uint256 collateralValue, uint256 debtValue) = SiloSolvencyLib.getPositionValues(ltvData, any, any);

        assertEq(collateralValue, collateralAssets + protectedAssets, "collateralValue");
        assertEq(debtValue, debtAssets, "debtValue");
    }

    /*
    forge test -vv --mt test_SiloSolvencyLib_getPositionValues_pass
    */
    function test_SiloSolvencyLib_getPositionValues_pass() public {
        address collateralOracle = address(0x555555);
        address debtOracle = address(0x77777);
        uint256 protectedAssets = 10;
        uint256 collateralAssets = 20;
        uint256 debtAssets = 3;

        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.LtvData(
            ISiloOracle(collateralOracle),
            ISiloOracle(debtOracle),
            protectedAssets,
            collateralAssets,
            debtAssets
        );

        address collateralAsset = address(0xc01a);
        address debtAsset = address(0xdeb);

        vm.mockCall(
            collateralOracle,
            abi.encodeWithSelector(ISiloOracle.quote.selector, ltvData.borrowerCollateralAssets + ltvData.borrowerProtectedAssets, collateralAsset),
            abi.encode(uint256(9876))
        );

        vm.mockCall(
            debtOracle,
            abi.encodeWithSelector(ISiloOracle.quote.selector, ltvData.borrowerDebtAssets, debtAsset),
            abi.encode(uint256(1234))
        );

        (
            uint256 collateralValue, uint256 debtValue
        ) = SiloSolvencyLib.getPositionValues(ltvData, collateralAsset, debtAsset);

        assertEq(collateralValue, 9876, "collateralValue");
        assertEq(debtValue, 1234, "debtValue");
    }
}
