import "./SiloConfigMethods.spec";
import "./ERC20MethodsDispatch.spec";
import "./Token0Methods.spec";
import "./Silo0ShareTokensMethods.spec";

using Silo0 as silo0;

function silo0SetUp(env e) {
    address configSilo0;
    address configSilo1;

    configSilo0, configSilo1 = siloConfig.getSilos();

    require configSilo0 == currentContract;

    require configSilo1 != token0;
    require configSilo1 != shareProtectedCollateralToken0;
    require configSilo1 != shareDebtToken0;
    require configSilo1 != shareCollateralToken0;
    require configSilo1 != siloConfig;
    require configSilo1 != currentContract;

    address configProtectedShareToken;
    address configCollateralShareToken;
    address configDebtShareToken;

    configProtectedShareToken, configCollateralShareToken, configDebtShareToken = siloConfig.getShareTokens(currentContract);

    require configProtectedShareToken == shareProtectedCollateralToken0;
    require configCollateralShareToken == shareCollateralToken0;
    require configDebtShareToken == shareDebtToken0;

    address configToken0 = siloConfig.getAssetForSilo(silo0);
    address configSiloToken1 = siloConfig.getAssetForSilo(configSilo1);

    require configToken0 == token0;

    require configSiloToken1 != silo0;
    require configSiloToken1 != configSilo1;
    require configSiloToken1 != token0;
    require configSiloToken1 != shareProtectedCollateralToken0;
    require configSiloToken1 != shareDebtToken0;
    require configSiloToken1 != shareCollateralToken0;
    require configSiloToken1 != siloConfig;
    require configSiloToken1 != currentContract;

    require e.msg.sender != shareProtectedCollateralToken0;
    require e.msg.sender != shareDebtToken0;
    require e.msg.sender != shareCollateralToken0;
    require e.msg.sender != siloConfig;
    require e.msg.sender != configSilo1;
    require e.msg.sender != silo0;

    // we can not have block.timestamp less than interestRateTimestamp
    require e.block.timestamp >= silo0.getSiloDataInterestRateTimestamp();
    require e.block.timestamp < max_uint64;

    // it is possible to deploy config with any fees, but not when you do it via factory
    // below are restrictions for fees we have in factory, if we not keep them we can overflow,
    require silo0.getDaoFee() <= 4 * (10 ^ 17); // 0.4e18;
    require silo0.getDeployerFee() <= 15 * (10 ^ 16); // 0.15e18;
}
