import "./SiloConfigMethods.spec";
import "./ERC20MethodsDispatch.spec";
import "./Token0Methods.spec";
import "./Silo0ShareTokensMethods.spec";

function silo0SetUp(env e) {
    address silo0;
    address silo1;

    silo0, silo1 = siloConfig.getSilos();

    require silo0 == currentContract;

    require silo1 != Token0;
    require silo1 != shareProtectedCollateralToken0;
    require silo1 != shareDebtToken0;
    require silo1 != shareCollateralToken0;
    require silo1 != siloConfig;
    require silo1 != currentContract;

    address configProtectedShareToken;
    address configCollateralShareToken;
    address configDebtShareToken;

    configProtectedShareToken, configCollateralShareToken, configDebtShareToken = siloConfig.getShareTokens(currentContract);

    require configProtectedShareToken == shareProtectedCollateralToken0;
    require configCollateralShareToken == shareCollateralToken0;
    require configDebtShareToken == shareDebtToken0;

    address configToken0 = siloConfig.getAssetForSilo(silo0);
    address configSiloToken1 = siloConfig.getAssetForSilo(silo1);

    require configToken0 == Token0;

    require configSiloToken1 != silo0;
    require configSiloToken1 != silo1;
    require configSiloToken1 != Token0;
    require configSiloToken1 != shareProtectedCollateralToken0;
    require configSiloToken1 != shareDebtToken0;
    require configSiloToken1 != shareCollateralToken0;
    require configSiloToken1 != siloConfig;
    require configSiloToken1 != currentContract;

    require e.msg.sender != shareProtectedCollateralToken0;
    require e.msg.sender != shareDebtToken0;
    require e.msg.sender != shareCollateralToken0;
    require e.msg.sender != siloConfig;
    require e.msg.sender != silo1;
}
