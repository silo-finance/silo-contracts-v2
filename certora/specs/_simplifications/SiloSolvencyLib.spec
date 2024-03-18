methods {
    // Summarizations:
    /*function SiloSolvencyLib.calculateLtv(
        SiloSolvencyLib.LtvData memory _ltvData, 
        address _collateralToken, 
        address _debtToken
    ) internal returns (uint256,uint256,uint256) =>
    calculateLtvCVL(_ltvData, _collateralToken, _debtToken);
*/

    /*function getAssetsDataForLtvCalculations(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower,
        ISilo.OracleType _oracleType,
        ISilo.AccrueInterestInMemory _accrueInMemory,
        uint256 _debtShareBalanceCached
    ) internal view returns (LtvData memory ltvData);*/
    
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