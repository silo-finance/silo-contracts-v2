import "../silo/_common/Silo0ShareTokensMethods.spec";
import "./SiloMathLib.spec";

methods {
    // Summarizations:
    /*function SiloSolvencyLib.calculateLtv(
        SiloSolvencyLib.LtvData memory _ltvData, 
        address _collateralToken, 
        address _debtToken
    ) internal returns (uint256,uint256,uint256) =>
    calculateLtvCVL(_ltvData, _collateralToken, _debtToken);
    */
    /*
    function SiloSolvencyLib.getAssetsDataForLtvCalculations(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower,
        ISilo.OracleType _oracleType,
        ISilo.AccrueInterestInMemory _accrueInMemory,
        uint256 _debtShareBalanceCached
    ) internal returns (SiloSolvencyLib.LtvData memory) =>
    calculateAssetsDataCVL(_collateralConfig.silo, _debtConfig.silo, _borrower, _debtShareBalanceCached);
    */
}


/*
ltvData

address collateralOracle
address debtOracle
uint256 borrowerProtectedAssets;
uint256 borrowerCollateralAssets;
uint256 borrowerDebtAssets;
*/

ghost abstractLTV_collateralValue(address,address,uint256,uint256,uint256) returns uint256;
ghost abstractLTV_debtValue(address,address,uint256,uint256,uint256) returns uint256;
ghost abstractLTV_ltvBefore(address,address,uint256,uint256,uint256) returns uint256;


function calculateLtvCVL(SiloSolvencyLib.LtvData ltvData, address collateralToken, address debtToken) returns (uint256,uint256,uint256) {
    uint256 x = ltvData.borrowerProtectedAssets;
    uint256 y = ltvData.borrowerCollateralAssets;
    uint256 z = ltvData.borrowerDebtAssets;
    return (
        abstractLTV_collateralValue(collateralToken, debtToken, x, y, z),
        abstractLTV_debtValue(collateralToken, debtToken, x, y, z),
        abstractLTV_ltvBefore(collateralToken, debtToken, x, y, z)
    );
}

function calculateAssetsDataCVL(address silo_collateral, address silo_debt, address borrower, uint256 debtShareBalanceCached) returns SiloSolvencyLib.LtvData {
    uint256 balanceCollateral;
    uint256 balanceProtectedCollateral;
    SiloSolvencyLib.LtvData ltvData;
    /// Fetch collateral data
    if(silo_collateral == silo0) {
        assert true;
    }
    else if(silo_collateral == silo1) {
        assert true;
    }
    else {
        assert false, "Only silo0 or silo1 are expected.";
    }

    /// Fetch debt data
    if(silo_debt == silo0) {
        assert true;
    }
    else if(silo_debt == silo1) {
        assert true;
    }
    else {
        assert false, "Only silo0 or silo1 are expected.";
    }

    //require ltvData.borrowerProtectedAssets == F();
    //require ltvData.borrowerCollateralAssets == G();
    //require ltvData.borrowerDebtAssets == H();

    return ltvData;
}
