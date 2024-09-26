using SiloConfig as siloConfig;

methods {
    // Summaries for all the siloConfig getters 
    function siloConfig.getAssetForSilo(
        address _silo
    ) external returns(address) => getAssetForSiloSumm(_silo) DELETE;
    
    function siloConfig.getSilos() external returns (address, address) => getSilosSumm() DELETE;
    
    function siloConfig.getShareTokens(
        address _silo
    ) external returns (address, address, address) => getShareTokensSumm(_silo) DELETE;
    
    function siloConfig.getFeesWithAsset(
        address _silo
    ) external returns(uint256, uint256, uint256, address) => getFeesWithAssetSumm(_silo) DELETE;
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

function getShareTokensSumm(address _silo) returns (address, address, address) {
	if(_silo == silo0) {
		  return (shareProtectedCollateralToken0, silo0, shareDebtToken0);
      } 
      else if(_silo == silo1) {
		  return (shareProtectedCollateralToken1, silo1, shareDebtToken1);
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
        require data.protectedShareToken == shareProtectedCollateralToken0;
        require data.collateralShareToken == silo0;
        require data.debtShareToken == shareDebtToken0;
        require data.token == token0;
        require data.flashloanFee == flashloanFee0;
        require data.solvencyOracle == solvencyOracle0;
        require data.maxLtvOracle == maxLtvOracle0;
        require data.lt == lt0;
    }
    else if(_silo == silo1) { 
        require data.silo == silo1;
        require data.protectedShareToken == shareProtectedCollateralToken1;
        require data.collateralShareToken == silo1;
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

function getConfigsSumm(address _silo) returns (ISiloConfig.ConfigData,ISiloConfig.ConfigData) {
    ISiloConfig.ConfigData configData0 = getConfigSumm(silo0);
    ISiloConfig.ConfigData configData1 = getConfigSumm(silo1);
    if (_silo == silo0) {
        return (configData0, configData1);
    } 
    else if (_silo == silo1) {
        return (configData1, configData0);
    } 
    else {
       assert false, "Did not expect a silo instance different from Silo0 and Silo1";
       return (_,_);
    }
}
