import "../summaries/two_silos_summaries.spec";
import "../summaries/siloconfig_dispatchers.spec";
import "../summaries/config_for_two_in_cvl.spec";
import "../summaries/tokens_dispatchers.spec";
import "../summaries/safe-approximations.spec";
import "../requirements/tokens_requirements.spec";

using Silo0 as silo0;
using Silo1 as silo1;
using ShareDebtToken0 as shareDebtToken0;
using ShareProtectedCollateralToken0 as shareProtectedCollateralToken0;
using ShareDebtToken1 as shareDebtToken1;
using ShareProtectedCollateralToken1 as shareProtectedCollateralToken1;
using EmptyHookReceiver as hookReceiver;
using SiloConfig as siloConfig; 

methods {
    // Summarizations:
    function SiloSolvencyLib.isSolvent(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address borrower,
        ISilo.AccrueInterestInMemory _accrueInMemory
    )  internal returns (bool) => updateSolvent(borrower);

    // Since `getCompoundInterestRateAndUpdate` is not view, this is not strictly sound.
    function _.getCompoundInterestRateAndUpdate(
        uint256 _collateralAssets,
        uint256 _debtAssets,
        uint256 _interestRateTimestamp
    ) external => NONDET;

    // ---- `ISiloOracle` ------------------------------------------------------
    // NOTE: Since `beforeQuote` is not a view function, strictly speaking this is unsound.
    function _.beforeQuote(address) external => NONDET DELETE;
    function _.synchronizeHooks(uint24,uint24) external => NONDET;


    // Unresolved calls are assumed to be nondet 
     function _.onFlashLoan(address _initiator, address _token, uint256 _amount, uint256 _fee, bytes  _data) external => NONDET;
     unresolved external in Silo0.callOnBehalfOfSilo(address,uint256,uint8,bytes) => DISPATCH(use_fallback=true) [
        
    ] default NONDET;

    function silo0.getTransferWithChecks() external  returns (bool) envfree;
    function siloConfig.getDebtSilo(address) external returns (address) envfree;
    //function ERC20Upgradeable._getERC20Storage() internal  returns (ERC20Upgradeable.ERC20Storage) => STORAGE_SLOT(); 
    function _.isSolvent(address) external => DISPATCHER(true);
}

/*function STORAGE_SLOT() returns address {
    return 37439836327923360225337895871394760624280537466773280374265222508165906222594;
}*/

ghost mapping(address => bool) simplified_solvent;

function updateSolvent(address user) returns bool {
    simplified_solvent[user] = true;
    return true;
}



invariant transferWithChecksAlwaysOn() 
        getTransferWithChecks() 
        {
            preserved with (env e) {
                configForEightTokensSetupRequirements();
                nonSceneAddressRequirements(e.msg.sender);
                silosTimestampSetupRequirements(e);
            }
        }

//@title A solvent user (at a specific timestamp) can not become insolvent by any operation 
rule solvnetChecked(method f)
{
    env e;
    address user; 
    configForEightTokensSetupRequirements();
    nonSceneAddressRequirements(e.msg.sender);
    silosTimestampSetupRequirements(e);

    requireInvariant transferWithChecksAlwaysOn(); 
    require siloConfig.borrowerCollateralSilo[user] == silo0;
    require siloConfig.getDebtSilo(user) == silo1; 

    SiloConfig.DepositConfig depositConfig;
    SiloConfig.ConfigData collateralConfig;
    SiloConfig.ConfigData debtConfig;

    depositConfig,collateralConfig,debtConfig  = siloConfig.getConfigsForWithdraw(e,silo0, user);
    satisfy true;
/*
    
    uint256 userSilo0BalancePre = silo0.balanceOf(user);
    uint256 userDebt0BalancePre = shareDebtToken0.balanceOf(user);
    uint256 userProtected0BalancePre = shareProtectedCollateralToken0.balanceOf(user);

    
    calldataarg args;
    f(e,args);

    uint256 userSilo0BalancePost = silo0.balanceOf(user);
    uint256 userDebt0BalancePost = shareDebtToken0.balanceOf(user);
    uint256 userProtected0BalancePost = shareProtectedCollateralToken0.balanceOf(user);

    assert  ( userSilo0BalancePre > userSilo0BalancePost || userDebt0BalancePre < userDebt0BalancePost) =>
            simplified_solvent[user]; */
}


hook Sstore silo0.(slot 37439836327923360225337895871394760624280537466773280374265222508165906222594).(offset 0)[KEY address user ] uint256 new_val (uint256 old_val) {
    inHook = true;
    if (new_val < old_val) {
        simplified_solvent[user] = false;
    }
} 

ghost bool inHook; 
rule checkhook(method f) {
    inHook = false;
    env e;
    calldataarg args;
    f(e,args);
    satisfy inHook; 
}
