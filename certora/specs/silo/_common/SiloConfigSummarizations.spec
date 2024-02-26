using SiloConfig as siloConfig;

methods {
    // Summaries for all the siloConfig getters 
    function siloConfig.getAssetForSilo(address _silo) external returns(address) envfree => getAssetForSiloSumm(_silo) DELETE;
    
    function siloConfig.getSilos() external returns(address, address) envfree => getSilosSumm() DELETE;
    
    // returns (address protectedShareToken, address collateralShareToken, address debtShareToken)
    function siloConfig.getShareTokens(address _silo) external returns(address, address, address) envfree => getShareTokensSumm(_silo) DELETE;
    
    // returns (uint256 daoFee, uint256 deployerFee, uint256 flashloanFee, address asset)
    function siloConfig.getFeesWithAsset(address _silo) external returns(uint256, uint256, uint256, address) envfree => getFeesWithAssetSumm(_silo) DELETE;

    function siloConfig.getConfig(address _silo) external returns(ISiloConfig.ConfigData memory) envfree => getConfigSumm(_silo) DELETE;

    function siloConfig.getConfigs(address _silo) external returns(ISiloConfig.ConfigData memory,ISiloConfig.ConfigData memory) envfree => getConfigsSumm(_silo) DELETE;
}


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
    if(_silo == silo0) {
        require data.silo == silo0;
        require data.otherSilo == silo1;
        require data.protectedShareToken == shareProtectedCollateralToken0;
        require data.collateralShareToken == shareCollateralToken0;
        require data.debtShareToken == shareDebtToken0;
        require data.token == token0;
    }
    else if(_silo == silo1) { 
        require data.silo == silo1;
        require data.otherSilo == silo0;
        require data.protectedShareToken == shareProtectedCollateralToken1;
        require data.collateralShareToken == shareCollateralToken1;
        require data.debtShareToken == shareDebtToken1;
        require data.token == token1;
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

ghost uint256 daoFee;
ghost uint256 deployerFee;
ghost uint256 flashloanFee0;
ghost uint256 flashloanFee1;

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