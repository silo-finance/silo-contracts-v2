using Silo0 as silo0;
using Silo1 as silo1;

methods {
    // Getters:

    function silo0.config() external returns(address) envfree;
    function silo1.config() external returns(address) envfree;

    function silo0.factory() external returns(address) envfree;
    function silo1.factory() external returns(address) envfree;

    function silo0.total(uint256) external returns(uint256) envfree;
    function silo1.total(uint256) external returns(uint256) envfree;

    function _.total(uint256) external => DISPATCHER(true);

    function silo0.getCollateralAssets() external returns(uint256);
    function silo1.getCollateralAssets() external returns(uint256);

    function silo0.getDebtAssets() external returns(uint256);
    function silo1.getDebtAssets() external returns(uint256);

    function silo0.getCollateralAndProtectedAssets() external returns(uint256,uint256) envfree;
    function silo1.getCollateralAndProtectedAssets() external returns(uint256,uint256) envfree;

    function _.getCollateralAndProtectedAssets() external => DISPATCHER(true);

    function silo0.getCollateralAndDebtAssets() external returns(uint256,uint256) envfree;
    function silo1.getCollateralAndDebtAssets() external returns(uint256,uint256) envfree;
    
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

    // IHookReceiver methods
    //function IHookReceiver.initialize(iSiloConfig, bytes) external => DISPATCHER(true);
    function _.beforeAction(address, uint256, bytes) external => DISPATCHER(true);
    function _.afterAction(address, uint256, bytes) external => DISPATCHER(true);
 
    // actions

    // function Actions.deposit(
    //     ISilo.SharedStorage storage _shareStorage,
    //     uint256 _assets,
    //     uint256 _shares,
    //     address _receiver,
    //     ISilo.CollateralType _collateralType,
    //     ISilo.Assets storage _totalCollateral
    // ) external returns (uint256, uint256) => actions_deposit_summ(
    //     _shareStorage, _assets, _shares, _receiver, _collateralType, _totalCollateral);

}

// function actions_deposit_summ(ISilo.SharedStorage _shareStorage,
//         uint256 _assets,
//         uint256 _shares,
//         address _receiver,
//         ISilo.CollateralType _collateralType,
//         ISilo.Assets _totalCollateral) returns (uint256, uint256)
//     {
//         return (0, 0);
//     }