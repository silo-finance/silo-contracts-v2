using SiloConfig as siloConfig;

using Silo0 as Silo0Contract;
using Silo1 as Silo1Contract;

methods {
    // Summaries for all the siloConfig getters 
    function siloConfig.getAssetForSilo(address _silo) external returns(address) => getAssetForSiloSumm(_silo) DELETE;
    
    function siloConfig.getSilos() external returns(address, address) => getSilosSumm() DELETE;
    
    // returns (address protectedShareToken, address collateralShareToken, address debtShareToken)
    function siloConfig.getShareTokens(address _silo) external returns(address, address, address) => getShareTokensSumm(_silo) DELETE;
    
    // returns (uint256 daoFee, uint256 deployerFee, uint256 flashloanFee, address asset)
    function siloConfig.getFeesWithAsset(address _silo) external returns(uint256, uint256, uint256, address) => getFeesWithAssetSumm(_silo) DELETE;

    //function _.getConfig(address _silo) external returns(ISiloConfig.ConfigData memory) => getConfigSumm(_silo) DELETE;
    function siloConfig.getConfig(address _silo) external returns(ISiloConfig.ConfigData memory) => getConfigSumm(_silo) DELETE;

    function siloConfig.getConfigs(address _silo, address _borrower, uint256 _action) external 
                    returns(ISiloConfig.ConfigData memory, ISiloConfig.ConfigData memory, ISiloConfig.DebtInfo memory) => getConfigsSumm(_silo, _borrower, _action) DELETE;

    // v 6.1 added:

    function siloConfig.crossNonReentrantBefore(uint256 _action) external;
    function siloConfig.crossNonReentrantAfter() external;
    function siloConfig.onDebtTransfer(address _sender, address _recipient) external;
    function siloConfig.closeDebt(address _borrower) external;

    function siloConfig.accrueInterestAndGetConfig(address _silo, uint256 _action) external 
            returns(ISiloConfig.ConfigData memory);
    function siloConfig.accrueInterestAndGetConfigOptimised(uint256 _action, ISilo.CollateralType _collateralType) 
            external returns (address, address, address, address); 
    function siloConfig.accrueInterestAndGetConfigOptimised(uint256 _action, ISilo.CollateralType _collateralType) 
            external returns (address, address, address, address);
    function siloConfig.accrueInterestAndGetConfigs(address _silo, address _borrower, uint256 _action) external 
            returns (ISiloConfig.ConfigData memory, ISiloConfig.ConfigData memory, ISiloConfig.DebtInfo memory);
    function siloConfig.crossReentrancyGuardEntered() external returns (bool);         

    function siloConfig._callAccrueInterest(address _silo) internal with (env e) => callAccrueInterestSumm(e, _silo);
}

definition MAX_LTV_PERCENT() returns uint256 = 10^18;
definition maxDaoFee() returns uint256 = 4 * (10 ^ 17); // 0.4e18;
definition maxDeployerFee() returns uint256 = 15 * (10 ^ 16); // 0.15e18;

 /** 
 @notice It is possible to deploy config with any fees, but not when you do it via factory.
 Below are restrictions (specified through axioms) for fees we have in factory; if we do not keep them, we can overflow.
 */
ghost uint256 daoFee {
    axiom daoFee <= maxDaoFee();
}

ghost uint256 deployerFee {
    axiom deployerFee <= maxDeployerFee();
}

ghost uint256 flashloanFee0;
ghost uint256 flashloanFee1;
ghost address solvencyOracle0;
ghost address maxLtvOracle0;
ghost address solvencyOracle1;
ghost address maxLtvOracle1;
ghost uint256 lt0;
ghost uint256 lt1;

ghost address interestRateModel0;
ghost address interestRateModel1;

ghost address liquidationModule;
ghost address hookReceiver;

/*
hook Sload address addr SiloConfig._PROTECTED_COLLATERAL_SHARE_TOKEN0 {
    require addr == shareProtectedCollateralToken0;
}

hook Sload address addr SiloConfig._COLLATERAL_SHARE_TOKEN0 {
    require addr == shareCollateralToken0;
}

hook Sload address addr SiloConfig._DEBT_SHARE_TOKEN0 {
    require addr == shareDebtToken0;
}

hook Sload address addr SiloConfig._PROTECTED_COLLATERAL_SHARE_TOKEN1 {
    require addr == shareProtectedCollateralToken1;
}

hook Sload address addr SiloConfig._COLLATERAL_SHARE_TOKEN1 {
    require addr == shareCollateralToken1;
}

hook Sload address addr SiloConfig._DEBT_SHARE_TOKEN1 {
    require addr == shareDebtToken1;
}

hook Sload address addr SiloConfig._SILO0 {
    require addr == silo0;
}

hook Sload address addr SiloConfig._SILO1 {
    require addr == silo1;
}

hook Sload address addr SiloConfig._TOKEN0 {
    require addr == token0;
}

hook Sload address addr SiloConfig._TOKEN1 {
    require addr == token1;
}

hook Sload address addr SiloConfig._LIQUIDATION_MODULE {
    require addr == liquidationModule;
}
*/

ghost mapping(address => bool) debtPresentGhost;
ghost mapping(address => bool) sameAssetGhost;
ghost mapping(address => bool) debtInSilo0Ghost;
ghost mapping(address => bool) debtInThisSiloGhost;

function getShareTokensSumm(address _silo) returns (address, address, address) {
	if(_silo == silo0) {
		  return (shareProtectedCollateralToken0, shareCollateralToken0, shareDebtToken0);
      } 
      else if(_silo == silo1) {
		  return (shareProtectedCollateralToken1, shareCollateralToken1, shareDebtToken1);
      } 
      else {
		  assert false, "Did not expect a silo instance different from Silo0 and Silo1";
		  return (_, _, _);
	  }
}

function getConfigSumm(address _silo) returns ISiloConfig.ConfigData {
    ISiloConfig.ConfigData data;
    require data.daoFee == daoFee;
    require data.deployerFee == deployerFee;
    require data.lt <= MAX_LTV_PERCENT() && data.maxLtv > 0;
    require data.maxLtv <= data.lt;
    if(_silo == silo0) {
        require data.silo == silo0;
        require data.otherSilo == silo1;
        require data.protectedShareToken == shareProtectedCollateralToken0;
        require data.collateralShareToken == shareCollateralToken0;
        require data.debtShareToken == shareDebtToken0;
        require data.token == token0;
        require data.flashloanFee == flashloanFee0;
        require data.solvencyOracle == solvencyOracle0;
        require data.maxLtvOracle == maxLtvOracle0;
        require data.lt == lt0;
    }
    else if(_silo == silo1) { 
        require data.silo == silo1;
        require data.otherSilo == silo0;
        require data.protectedShareToken == shareProtectedCollateralToken1;
        require data.collateralShareToken == shareCollateralToken1;
        require data.debtShareToken == shareDebtToken1;
        require data.token == token1;
        require data.flashloanFee == flashloanFee1;
        require data.solvencyOracle == solvencyOracle1;
        require data.maxLtvOracle == maxLtvOracle1;
        require data.lt == lt1;
    }
    else {
        assert false, "Did not expect a silo instance different from Silo0 and Silo1";
    }
    return data;
}

function getSilosSumm() returns (address, address) {
    return (silo0, silo1);
}

function getAssetForSiloSumm(address _silo) returns address {
    if(_silo == silo0) {
        return token0;
    } 
    else if (_silo == silo1) {
        return token1;
    } 
    else {
        assert false, "Did not expect a silo instance different from Silo0 and Silo1";
		return _;
    }
}

function getFeesWithAssetSumm(address _silo) returns (uint256, uint256, uint256, address) {
    if (_silo == silo0) {
        return (daoFee, deployerFee, flashloanFee0, token0);
    } 
    else if (_silo == silo1) {
        return (daoFee, deployerFee, flashloanFee1, token1);
    } 
    else {
        assert false, "Did not expect a silo instance different from Silo0 and Silo1";
		return (_, _, _, _);
    }
}

function getConfigsSumm(address _silo, address _borrower, uint256 _action) 
            returns (ISiloConfig.ConfigData, ISiloConfig.ConfigData, ISiloConfig.DebtInfo) 
{
    ISiloConfig.ConfigData configData0 = getConfigSumm(silo0);
    ISiloConfig.ConfigData configData1 = getConfigSumm(silo1);
    ISiloConfig.DebtInfo debtInfo = getDebtInfo(_borrower);
    if (_silo == silo0) {
        return (configData0, configData1, debtInfo);
    } 
    else if (_silo == silo1) {
        return (configData1, configData0, debtInfo);
    } 
    else {
       assert false, "Did not expect a silo instance different from Silo0 and Silo1";
       return (_,_,_);
    }
}

function getDebtInfo(address borrower) returns ISiloConfig.DebtInfo {
    ISiloConfig.DebtInfo debtInfo;
    require debtInfo.debtPresent == debtPresentGhost[borrower];
    require debtInfo.sameAsset == sameAssetGhost[borrower];
    require debtInfo.debtInSilo0 == debtInSilo0Ghost[borrower];
    require debtInfo.debtInThisSilo == debtInThisSiloGhost[borrower];
    return debtInfo;
}

function callAccrueInterestSumm(env e, address _silo)
{
    if (_silo == silo0) {
        Silo0Contract.accrueInterestForConfig(e, interestRateModel0, daoFee, deployerFee);
    } 
    else if (_silo == silo1) {
        Silo1Contract.accrueInterestForConfig(e, interestRateModel1, daoFee, deployerFee);
    } 
    else {
        assert false, "Did not expect a silo instance different from Silo0 and Silo1";
    }
}

function isPublicCall(env e) returns bool {
    if (e.msg.sender != silo0 &&
        e.msg.sender != silo1 &&
        e.msg.sender != liquidationModule &&
        e.msg.sender != shareCollateralToken0 &&
        e.msg.sender != shareCollateralToken1 &&
        e.msg.sender != shareProtectedCollateralToken0 &&
        e.msg.sender != shareProtectedCollateralToken1 &&
        e.msg.sender != shareDebtToken0 &&
        e.msg.sender != shareDebtToken1
    ) {
        return true;
    }
    return false;
}

function requireCorrectLinking()
{ 
    require siloConfig._PROTECTED_COLLATERAL_SHARE_TOKEN0 == shareProtectedCollateralToken0;
    require siloConfig._COLLATERAL_SHARE_TOKEN0 == shareCollateralToken0;
    require siloConfig._DEBT_SHARE_TOKEN0 == shareDebtToken0;
    require siloConfig._PROTECTED_COLLATERAL_SHARE_TOKEN1 == shareProtectedCollateralToken1;
    require siloConfig._COLLATERAL_SHARE_TOKEN1 == shareCollateralToken1;
    require siloConfig._DEBT_SHARE_TOKEN1 == shareDebtToken1;
    require siloConfig._SILO0 == silo0;
    require siloConfig._SILO1 == silo1;
    require siloConfig._TOKEN0 == token0;
    require siloConfig._TOKEN1 == token1;
    require siloConfig._LIQUIDATION_MODULE == liquidationModule;
}