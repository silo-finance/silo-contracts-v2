import "./IsSiloFunction.spec";
import "./Helpers.spec";
import "./CommonSummarizations.spec";
import "./SiloConfigSummarizations.spec";
import "./ERC20MethodsDispatch.spec";
import "./Token0Methods.spec";
import "./Token1Methods.spec";
import "./Silo0ShareTokensMethods.spec";
import "./Silo1ShareTokensMethods.spec";

function completeSiloSetupEnv(env e) {
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

    // we can not have block.timestamp less than interestRateTimestamp
    uint256 blockTimestamp = require_uint64(e.block.timestamp);
    require blockTimestamp >= silo0.getSiloDataInterestRateTimestamp(e);
    require blockTimestamp >= silo1.getSiloDataInterestRateTimestamp(e);
}
