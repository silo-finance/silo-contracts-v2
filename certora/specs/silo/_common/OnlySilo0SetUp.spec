import "./SiloConfigMethods.spec";
import "./Token0Methods.spec";
import "./Silo0TokensCommonMethods.spec";
import "./Silo0ShareTokensMethods.spec";

using Silo0 as silo0;

definition maxDaoFee() returns uint256 = 4 * (10 ^ 17); // 0.4e18;
definition maxDeployerFee() returns uint256 = 15 * (10 ^ 16); // 0.15e18;

function silo0SetUp(env e) {
    address configSilo1;

    _, configSilo1 = siloConfig.getSilos();

    require configSilo1 != token0;
    require configSilo1 != shareProtectedCollateralToken0;
    require configSilo1 != shareDebtToken0;
    require configSilo1 != shareCollateralToken0;
    require configSilo1 != siloConfig;

    address configProtectedShareToken;
    address configCollateralShareToken;
    address configDebtShareToken;

    configProtectedShareToken, configCollateralShareToken, configDebtShareToken = siloConfig.getShareTokens(currentContract);

    address configProtectedShareToken1;
    address configCollateralShareToken1;
    address configDebtShareToken1;

    configProtectedShareToken1, configCollateralShareToken1, configDebtShareToken1 = siloConfig.getShareTokens(configSilo1);

    require configDebtShareToken1 != configProtectedShareToken1;
    require configDebtShareToken1 != configCollateralShareToken1;
    require configDebtShareToken1 != configProtectedShareToken;
    require configDebtShareToken1 != configCollateralShareToken;

    address configToken0 = siloConfig.getAssetForSilo(silo0);
    address configSiloToken1 = siloConfig.getAssetForSilo(configSilo1);

    require configSiloToken1 != silo0;
    require configSiloToken1 != configSilo1;
    require configSiloToken1 != token0;
    require configSiloToken1 != shareProtectedCollateralToken0;
    require configSiloToken1 != shareDebtToken0;
    require configSiloToken1 != shareCollateralToken0;
    require configSiloToken1 != siloConfig;
    require configSiloToken1 != currentContract;
    require configSiloToken1 != configProtectedShareToken1;
    require configSiloToken1 != configDebtShareToken1;
    require configSiloToken1 != configCollateralShareToken1;

    require e.msg.sender != shareProtectedCollateralToken0;
    require e.msg.sender != shareDebtToken0;
    require e.msg.sender != shareCollateralToken0;
    require e.msg.sender != configProtectedShareToken1;
    require e.msg.sender != configDebtShareToken1;
    require e.msg.sender != configCollateralShareToken1;
    require e.msg.sender != siloConfig;
    require e.msg.sender != configSilo1;
    require e.msg.sender != silo0;

    // we can not have block.timestamp less than interestRateTimestamp
    require e.block.timestamp >= silo0.getSiloDataInterestRateTimestamp();
    require e.block.timestamp < max_uint64;

    // it is possible to deploy config with any fees, but not when you do it via factory
    // below are restrictions for fees we have in factory, if we do not keep them we can overflow,
    require silo0.getDaoFee() <= maxDaoFee(); 
    require silo0.getDeployerFee() <= maxDeployerFee();
}
