methods {
    // Getters:
    function config() external returns(address) envfree;
    function factory() external returns(address) envfree;
    function getProtectedAssets() external returns(uint256) envfree;
    function getCollateralAssets() external returns(uint256) envfree;
    function getDebtAssets() external returns(uint256) envfree;
    function getCollateralAndProtectedAssets() external returns(uint256,uint256) envfree;
    
    // Harness:
    function getSiloDataInterestRateTimestamp() external returns(uint256) envfree;
    function getSiloDataDaoAndDeployerFees() external returns(uint256) envfree;
    function getFlashloanFee0() external returns(uint256) envfree;
    function getFlashloanFee1() external returns(uint256) envfree;
    function reentrancyGuardEntered() external returns(bool) envfree;
    function getDaoFee() external returns(uint256) envfree;
    function getDeployerFee() external returns(uint256) envfree;
}
