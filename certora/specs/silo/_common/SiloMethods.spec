methods {
    // Getters:
    function config() external returns(address) envfree;
    function factory() external returns(address) envfree;
    function getProtectedAssets() external returns(uint256) envfree;
    function getCollateralAssets() external returns(uint256) envfree;
    function getDebtAssets() external returns(uint256) envfree;
    function getCollateralAndDebtAssets() external returns(uint256,uint256) envfree;
    function getCollateralAndProtectedAssets() external returns(uint256,uint256) envfree;
    function getLiquidity() external returns(uint256) envfree;

    function _.getDebtAssets() external => getDebtAssetsSumm(calledContract) expect uint256 UNRESOLVED;

    function _.getCollateralAndDebtAssets() external
        => getCollateralAndDebtAssetsSumm(calledContract) expect (uint256,uint256) UNRESOLVED;
    
    // Harness:
    function getSiloDataInterestRateTimestamp() external returns(uint256) envfree;
    function getSiloDataDaoAndDeployerFees() external returns(uint256) envfree;
    function getFlashloanFee0() external returns(uint256) envfree;
    function getFlashloanFee1() external returns(uint256) envfree;
    function reentrancyGuardEntered() external returns(bool) envfree;
    function getDaoFee() external returns(uint256) envfree;
    function getDeployerFee() external returns(uint256) envfree;
}

function getDebtAssetsSumm(address callee) returns uint256 {
    uint256 debtAssets;

    if(callee == silo0) {
        require debtAssets == silo0.getDebtAssets();
    } else {
        assert false, "Unresolved call to Silo getDebtAssets()";
    }

    return debtAssets;
}

function getCollateralAndDebtAssetsSumm(address callee) returns (uint256, uint256) {
    uint256 collateralAssets;
    uint256 debtAssets;

    if(callee == silo0) {
        uint256 collateralAssetsFromSilo;
        uint256 debtAssetsFromSilo;

        collateralAssetsFromSilo, debtAssetsFromSilo = silo0.getCollateralAndDebtAssets();

        require collateralAssets == collateralAssetsFromSilo;
        require debtAssets == debtAssetsFromSilo;
    } else {
        assert false, "Unresolved call to Silo getCollateralAndDebtAssets()";
    }

    return (collateralAssets, debtAssets);
}
