import "./SiloConfigMethods.spec";
import "./ERC20MethodsDispatch.spec";
import "./Token0Methods.spec";
import "./Token1Methods.spec";
import "./Silo0ShareTokensMethods.spec";
import "./Silo1ShareTokensMethods.spec";

using Silo0 as silo0;
using Silo1 as silo1;

function completeSiloSetUp(env e) {
    address configSilo0;
    address configSilo1;

    configSilo0, configSilo1 = siloConfig.getSilos();

    require configSilo0 == currentContract;
    require configSilo1 == silo1;

    address configProtectedShareToken0;
    address configCollateralShareToken0;
    address configDebtShareToken0;

    configProtectedShareToken0, configCollateralShareToken0, configDebtShareToken0 = siloConfig.getShareTokens(currentContract);

    require configProtectedShareToken0 == shareProtectedCollateralToken0;
    require configCollateralShareToken0 == shareCollateralToken0;
    require configDebtShareToken0 == shareDebtToken0;

    address configProtectedShareToken1;
    address configCollateralShareToken1;
    address configDebtShareToken1;

    configProtectedShareToken1, configCollateralShareToken1, configDebtShareToken1 = siloConfig.getShareTokens(currentContract);

    require configProtectedShareToken1 == shareProtectedCollateralToken1;
    require configCollateralShareToken1 == shareCollateralToken1;
    require configDebtShareToken1 == shareDebtToken1;

    address configToken0 = siloConfig.getAssetForSilo(silo0);
    address configToken1 = siloConfig.getAssetForSilo(silo1);

    require configToken0 == token0;
    require configToken1 == token1;

    require e.msg.sender != shareProtectedCollateralToken0;
    require e.msg.sender != shareDebtToken0;
    require e.msg.sender != shareCollateralToken0;
    require e.msg.sender != shareProtectedCollateralToken1;
    require e.msg.sender != shareDebtToken1;
    require e.msg.sender != shareCollateralToken1;
    require e.msg.sender != siloConfig;
    require e.msg.sender != silo0;
    require e.msg.sender != silo1;
    require e.msg.sender != token0;
    require e.msg.sender != token1;
}
