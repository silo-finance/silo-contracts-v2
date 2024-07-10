import "../_simplifications/priceOracle.spec";
import "../silo/_common/CommonSummarizations.spec";
import "../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";
import "../_simplifications/SiloMathLib.spec";

using Silo0 as silo0;
using Silo1 as silo1;
using SiloSolvencyLibHarness as Lib;

methods {
    function _.balanceOf(address borrower) external => generalBalance(calledContract, borrower) expect uint256;
    function _.totalSupply() external => generalTotalSupply(calledContract) expect uint256;
    function _.getCollateralAndDebtAssets() external => DISPATCHER(true);
    function _.getCollateralAndProtectedAssets() external => DISPATCHER(true);
    function _.total(ISiloMock.AssetType) external => DISPATCHER(true);
    function silo0.getSiloDataInterestRateTimestamp() external returns (uint256) envfree;
    function silo1.getSiloDataInterestRateTimestamp() external returns (uint256) envfree;

    function Lib.getAssetsDataForLtvCalculations(address,ISilo.OracleType,ISilo.AccrueInterestInMemory,uint256) external returns (uint256,uint256,uint256);
    function Lib.getSiloForCollateralConfig(bool) external returns (address) envfree;
    function Lib.getSiloForDebtConfig(bool) external returns (address) envfree;
    function Lib.getTokensOfDebtConfig() external returns (address,address,address,address) envfree;
    function Lib.getTokensOfCollateralConfig() external returns (address,address,address,address) envfree;
    function Lib.addNumToAddress(address, uint8) external returns (address) envfree;
}

ghost generalBalance(address, address) returns uint256 {
    axiom forall address token. forall address account. 
        generalBalance(token,account) <= generalTotalSupply(token);
    axiom forall address token. 
        forall address account1. forall address account2.
            account1 != account2 =>
            generalBalance(token,account1) + generalBalance(token,account2) <= 
            to_mathint(generalTotalSupply(token));
}

ghost generalTotalSupply(address) returns uint256;

function boundTotalCollateral(SiloSolvencyLib.LtvData data) {
    require data.borrowerProtectedAssets + data.borrowerCollateralAssets < max_uint256;
}

rule sanity(method f) {
    env e;
    calldataarg args;
    require e.block.timestamp >= silo0.getSiloDataInterestRateTimestamp();
    require e.block.timestamp >= silo1.getSiloDataInterestRateTimestamp();
    require silo0 == Lib.getSiloForCollateralConfig(true);
    require silo1 == Lib.getSiloForCollateralConfig(false);
    require silo1 == Lib.getSiloForDebtConfig(true);
    require silo0 == Lib.getSiloForDebtConfig(false);

    f(e, args);
    satisfy true;
}

function setup(env e) {
    address token0; address protected0; address coll0; address debt0;
    address token1; address protected1; address coll1; address debt1;
    token0, protected0, coll0, debt0 = Lib.getTokensOfDebtConfig();
    token1, protected1, coll1, debt1 = Lib.getTokensOfCollateralConfig();
    require silo1 == addNumToAddress(silo0, 100);
    require token0 == addNumToAddress(silo0, 1);
    require protected0 == addNumToAddress(silo0, 2);
    require coll0 == addNumToAddress(silo0, 3);
    require debt0 == addNumToAddress(silo0, 4);
    require token1 == addNumToAddress(silo1, 1);
    require protected1 == addNumToAddress(silo1, 2);
    require coll1 == addNumToAddress(silo1, 3);
    require debt1 == addNumToAddress(silo1, 4);

    require silo0 == Lib.getSiloForCollateralConfig(true);
    require silo1 == Lib.getSiloForCollateralConfig(false);
    require silo1 == Lib.getSiloForDebtConfig(true);
    require silo0 == Lib.getSiloForDebtConfig(false);

    require e.block.timestamp >= silo0.getSiloDataInterestRateTimestamp();
    require e.block.timestamp >= silo1.getSiloDataInterestRateTimestamp();
}

rule getAssetsDataForLtvCalculationsIsAmountMonotonic(uint256 amount1, uint256 amount2) {
    env e;
    setup(e);

    address borrower;
    ISilo.OracleType oracleType;
    ISilo.AccrueInterestInMemory accrue;
    uint256 debtAssets1; uint256 protectedAssets1; uint256 collateralAssets1;
    uint256 debtAssets2; uint256 protectedAssets2; uint256 collateralAssets2;
    
    /// Otherwise, returns zero.
    require amount1 > 0;

    protectedAssets1, collateralAssets1, debtAssets1 = Lib.getAssetsDataForLtvCalculations(e, borrower, oracleType, accrue, amount1);
    protectedAssets2, collateralAssets2, debtAssets2 = Lib.getAssetsDataForLtvCalculations(e, borrower, oracleType, accrue, amount2);

    assert amount1 < amount2 => protectedAssets1 <= protectedAssets2;
    assert amount1 < amount2 => collateralAssets1 <= collateralAssets2;
    assert amount1 < amount2 => debtAssets1 <= debtAssets2;
}

rule calculateLtVisMonotonic() {
    env e;
    setup(e);
    
    address collateralToken;
    address debtToken;
    SiloSolvencyLib.LtvData ltvData1;
    SiloSolvencyLib.LtvData ltvData2;

    uint256 sumOfBorrowerCollateralValue1; 
    uint256 totalBorrowerDebtValue1;
    uint256 ltvInDp1;

    uint256 sumOfBorrowerCollateralValue2; 
    uint256 totalBorrowerDebtValue2;
    uint256 ltvInDp2;

    sumOfBorrowerCollateralValue1,
    totalBorrowerDebtValue1,
    ltvInDp1 = 
        Lib.calculateLtv(e, ltvData1, collateralToken, debtToken);

    sumOfBorrowerCollateralValue2,
    totalBorrowerDebtValue2,
    ltvInDp2 = 
        Lib.calculateLtv(e, ltvData2, collateralToken, debtToken);

    require totalBorrowerDebtValue1 !=0;
    require totalBorrowerDebtValue2 !=0;
    require ltvData1.collateralOracle == ltvData2.collateralOracle;
    require ltvData1.debtOracle == ltvData2.debtOracle;
    boundTotalCollateral(ltvData1);
    boundTotalCollateral(ltvData2);

    assert
        ltvData1.borrowerProtectedAssets == ltvData2.borrowerProtectedAssets &&
        ltvData1.borrowerCollateralAssets == ltvData2.borrowerCollateralAssets &&
        ltvData1.borrowerDebtAssets < ltvData2.borrowerDebtAssets =>
        ltvInDp1 <= ltvInDp2;

    assert
        ltvData1.borrowerProtectedAssets < ltvData2.borrowerProtectedAssets &&
        ltvData1.borrowerCollateralAssets == ltvData2.borrowerCollateralAssets &&
        ltvData1.borrowerDebtAssets == ltvData2.borrowerDebtAssets =>
        ltvInDp1 >= ltvInDp2;

    assert
        ltvData1.borrowerProtectedAssets == ltvData2.borrowerProtectedAssets &&
        ltvData1.borrowerCollateralAssets < ltvData2.borrowerCollateralAssets &&
        ltvData1.borrowerDebtAssets == ltvData2.borrowerDebtAssets =>
        ltvInDp1 >= ltvInDp2;
}
