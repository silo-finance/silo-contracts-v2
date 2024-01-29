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

    // we can not have block.timestamp less than interestRateTimestamp, however is this something to prove as well?
    require e.block.timestamp >= silo0.getSiloDataInterestRateTimestamp();
    require e.block.timestamp < max_uint64;
}
