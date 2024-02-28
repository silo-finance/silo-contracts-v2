using Silo0 as silo0;
using Silo1 as silo1;

methods {
    // Getters:

    function silo0.config() external returns(address) envfree;
    function silo1.config() external returns(address) envfree;

    function silo0.factory() external returns(address) envfree;
    function silo1.factory() external returns(address) envfree;

    function silo0.total(ISilo.AssetType) external returns(uint256) envfree;
    function silo1.total(ISilo.AssetType) external returns(uint256) envfree;

    function _.total(ISilo.AssetType) external => DISPATCHER(true);

    function silo0.getCollateralAssets() external returns(uint256);
    function silo1.getCollateralAssets() external returns(uint256);

    function silo0.getDebtAssets() external returns(uint256);
    function silo1.getDebtAssets() external returns(uint256);

    function silo0.getCollateralAndProtectedAssets() external returns(uint256,uint256) envfree;
    function silo1.getCollateralAndProtectedAssets() external returns(uint256,uint256) envfree;

    function _.getCollateralAndProtectedAssets() external => DISPATCHER(true);

    function _.getCollateralAndDebtAssets() external => DISPATCHER(true);

    // Harness:
    function silo0.getSiloDataInterestRateTimestamp() external returns(uint256) envfree;
    function silo1.getSiloDataInterestRateTimestamp() external returns(uint256) envfree;

    function silo0.getSiloDataDaoAndDeployerFees() external returns(uint256) envfree;
    function silo1.getSiloDataDaoAndDeployerFees() external returns(uint256) envfree;

    function silo0.getFlashloanFee0() external returns(uint256) envfree;
    function silo1.getFlashloanFee0() external returns(uint256) envfree;

    function silo0.getFlashloanFee1() external returns(uint256) envfree;
    function silo1.getFlashloanFee1() external returns(uint256) envfree;

    function silo0.getFlashloanFee1() external returns(uint256) envfree;
    function silo1.getFlashloanFee1() external returns(uint256) envfree;

    function silo0.reentrancyGuardEntered() external returns(bool) envfree;
    function silo1.reentrancyGuardEntered() external returns(bool) envfree;
}