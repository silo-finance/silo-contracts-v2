/* High level properties example */
import "../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";
import "../erc20cvl.spec";
import "_common/SiloConfigSummarizations.spec";

using Silo0 as silo0;
using Silo1 as silo1;
using Token0 as token0;
using Token1 as token1;


methods {
    // ---- `Silo` -------------------------------------------------------------
    
    // NOTE: the following declarations are equivalent:
    // `function Silo0.config() external returns(address) envfree;`
    // `function config() external returns (address) envfree;`

    function config() external returns (address) envfree;
    function Silo1.config() external returns (address) envfree;
    
    function Silo0.getTotalAssetsStorage(uint256) external returns(uint256) envfree;
    function Silo1.getTotalAssetsStorage(uint256) external returns(uint256) envfree;

    // Harness
    function Silo0.getSiloDataInterestRateTimestamp() external returns(uint64) envfree;
    function Silo1.getSiloDataInterestRateTimestamp() external returns(uint64) envfree;

    function Silo0.getSiloDataDaoAndDeployerRevenue() external returns(uint192) envfree;
    function Silo1.getSiloDataDaoAndDeployerRevenue() external returns(uint192) envfree;

    // Dispatcher
    function _.accrueInterest() external => DISPATCHER(true);
    function _.getTotalAssetsStorage(uint256) external => DISPATCHER(true);
    function _.getCollateralAndProtectedTotalsStorage() external => DISPATCHER(true);

    // Accrue interest
    function _.accrueInterestForConfig(
        address, uint256, uint256
    ) external => DISPATCHER(true);

    // ---- `SiloConfig` -------------------------------------------------------
    function SiloConfig.accrueInterestForSilo(address) external envfree;
    function SiloConfig.getCollateralShareTokenAndAsset(
        address,
        ISilo.CollateralType
    ) external returns (address, address) envfree;

    function _.accrueInterestForSilo(address) external => DISPATCHER(true);
    function _.accrueInterestForBothSilos() external => DISPATCHER(true);
    function _.getConfigsForWithdraw(address,address) external => DISPATCHER(true);
    function _.getConfigsForBorrow(address) external  => DISPATCHER(true);
    function _.getConfigsForSolvency(address) external  => DISPATCHER(true);
    function _.getCollateralShareTokenAndAsset(
        address,
        ISilo.CollateralType
    ) external => DISPATCHER(true);

    function _.hasDebtInOtherSilo(address,address) external  => DISPATCHER(true);
    function _.setThisSiloAsCollateralSilo(address) external  => DISPATCHER(true);
    function _.setOtherSiloAsCollateralSilo(address) external  => DISPATCHER(true);
    function _.getConfig(address) external  => DISPATCHER(true);
    function _.getFeesWithAsset(address) external  => DISPATCHER(true);
    function _.borrowerCollateralSilo(address) external  => DISPATCHER(true);
    function _.onDebtTransfer(address,address) external  => DISPATCHER(true);

    // `CrossReentrancyGuard`
    function _.turnOnReentrancyProtection() external => DISPATCHER(true);
    function _.turnOffReentrancyProtection() external => DISPATCHER(true);

    // ---- `IERC3156FlashBorrower` --------------------------------------------
    // NOTE: Since `onFlashLoan` is not a view function, strictly speaking this is unsound.
    // function _.onFlashLoan(address,address,uint256,uint256,bytes) external => NONDET;

    // ---- `ISiloFactory` -----------------------------------------------------
    // NOTE: Strictly speaking summarizing `getFeeReceivers` as `CONSTANT` is an under
    // approximation.
    function _.getFeeReceivers(address) external => CONSTANT;

    // ---- `ShareToken` -------------------------------------------------------
    // NOTE: Summarizing `ShareToken._afterTokenTransfer` as `CONSTANT` is an under-approximation!
    // NOTE: Must be summarized since it calls `balanceOf` and `totalSupply`
    // function ShareToken._afterTokenTransfer(address,address,uint256) internal => CONSTANT;
    
    function Silo0.silo() external returns (address) envfree;
    function ShareDebtToken0.silo() external returns (address) envfree;
    function ShareProtectedCollateralToken0.silo() external returns (address) envfree;

    function Silo0.siloConfig() external returns (address) envfree;
    function ShareDebtToken0.siloConfig() external returns (address) envfree;
    function ShareProtectedCollateralToken0.siloConfig() external returns (address) envfree;

    function Silo1.silo() external returns (address) envfree;
    function ShareDebtToken1.silo() external returns (address) envfree;
    function ShareProtectedCollateralToken1.silo() external returns (address) envfree;

    function Silo1.siloConfig() external returns (address) envfree;
    function ShareDebtToken1.siloConfig() external returns (address) envfree;
    function ShareProtectedCollateralToken1.siloConfig() external returns (address) envfree;

    // ---- `Actions` ----------------------------------------------------------
    function Actions._hookCallBeforeBorrow(ISilo.BorrowArgs memory, uint256) internal => NONDET;
    
    // ---- `SiloSolvencyLib` --------------------------------------------------
    // NOTE: Simplifies the solvency calculation, probably not an under-approximation
    function SiloSolvencyLib.isSolvent(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower,
        ISilo.AccrueInterestInMemory _accrueInMemory
    ) internal returns (bool) => simplified_solvent(_debtConfig, _borrower);

    // ---- `ISiloOracle` ------------------------------------------------------
    // NOTE: Since `beforeQuote` is not a view function, strictly speaking this is unsound.
    function _.beforeQuote(address) external => NONDET;

    // NOTE: Summarizes as fixed price of 1 -- an under-approximation.
    function _.quote(
        uint256 _baseAmount,
        address _baseToken
    ) external  => price_is_one(_baseAmount, _baseToken) expect uint256;

    // ---- `IHookReceiver` ----------------------------------------------------
    // TODO: are these sound?
    function _.beforeAction(address, uint256, bytes) external => NONDET DELETE;
    function _.afterAction(address, uint256, bytes) external => NONDET DELETE;

    // ---- Mathematical simplifications ---------------------------------------
    function _.mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal => cvlMulDiv(x, y, denominator) expect uint256;
}

// ---- CVL summary functions --------------------------------------------------

/// @title `mulDiv` implementation in CVL
/// @notice This will never revert!
function cvlMulDiv(uint256 x, uint256 y, uint256 denominator) returns uint {
    require denominator != 0;
    return require_uint256(x * y / denominator);
}


/// @title Summarize `quote` as `_baseAmount`
function price_is_one(uint256 _baseAmount, address _baseToken) returns uint256 {
    return _baseAmount;
}


/// @title Ghost mapping: silo => borrower => is-solvent
ghost mapping(address => mapping(address => bool)) solvency_ghost;

/// @title A summary simplifying solvency calculations
function simplified_solvent(
    ISiloConfig.ConfigData _debtConfig,
    address _borrower
) returns bool {
    return solvency_ghost[_debtConfig.silo][_borrower];
}

// ---- Functions --------------------------------------------------------------

function doesntHaveCollateralAsWellAsDebt(address user)
{
    require !(  //cannot have collateral AND debt on `silo0`
            (balanceByToken[silo0][user] > 0 || 
             balanceByToken[shareProtectedCollateralToken0][user] > 0) &&
            balanceByToken[shareDebtToken0][user] > 0);

    require !(  //cannot have collateral AND debt on `silo1`
            (balanceByToken[silo1][user] > 0 || 
             balanceByToken[shareProtectedCollateralToken1][user] > 0) &&
            balanceByToken[shareDebtToken1][user] > 0);
}

function completeSiloSetupAddress(address sender)
{
    require sender != silo0;
    require sender != shareDebtToken0;
    require sender != shareProtectedCollateralToken0;
    require sender != shareProtectedCollateralToken1;
    require sender != shareDebtToken1;
    require sender != silo1;
    require sender != token0;
    require sender != token1;
    doesntHaveCollateralAsWellAsDebt(sender);

    //there are shares if and only if there are tokens
    //otherwise there are CEXs where borrow(a lot); repay(a little); removes all debt from the user, etc.
    require (
            totalSupplyByToken[shareDebtToken0] == 0 <=>
            silo0.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Debt)) == 0
            );  
    require (
            totalSupplyByToken[shareProtectedCollateralToken0] == 0 <=>
            silo0.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Protected)) == 0
            );
    require (
            totalSupplyByToken[silo0] == 0 <=>
            silo0.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Collateral)) == 0
            );

    require (
            totalSupplyByToken[shareDebtToken1] == 0 <=>
            silo1.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Debt)) == 0
            );
    require (
            totalSupplyByToken[shareProtectedCollateralToken1] == 0 <=>
            silo1.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Protected)) == 0
            );
    require (
            totalSupplyByToken[silo1] == 0 <=>
            silo1.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Collateral)) == 0
            );

}

function completeSiloSetupEnv(env e) {

    completeSiloSetupAddress(e.msg.sender);
    // we can not have block.timestamp less than interestRateTimestamp
    require e.block.timestamp < (1 << 64);
    require require_uint64(e.block.timestamp) >= silo0.getSiloDataInterestRateTimestamp(e);
    require require_uint64(e.block.timestamp) >= silo1.getSiloDataInterestRateTimestamp(e);
}


/// @title Sets up the tokens, shares and config
function setupTokensSharesConfig() {
    require silo0.silo() == silo0;
    require shareDebtToken0.silo() == silo0;
    require shareProtectedCollateralToken0.silo() == silo0;
    
    require silo0.config() == siloConfig;
    require silo0.siloConfig() == siloConfig;
    require shareDebtToken0.siloConfig() == siloConfig;
    require shareProtectedCollateralToken0.siloConfig() == siloConfig;

    require silo1.silo() == silo1;
    require shareDebtToken1.silo() == silo1;
    require shareProtectedCollateralToken1.silo() == silo1;
    
    require silo1.config() == siloConfig;
    require silo1.siloConfig() == siloConfig;
    require shareDebtToken1.siloConfig() == siloConfig;
    require shareProtectedCollateralToken1.siloConfig() == siloConfig;
}

// ---- Rules ------------------------------------------------------------------

/// @title Two mints are not better than one
rule HLP_mint_breakingUpNotBeneficial_full(env e, address receiver)
{
    completeSiloSetupEnv(e);
    setupTokensSharesConfig();

    totalSupplyMoreThanBalanceERC20(token0, receiver);
    totalSupplyMoreThanBalanceERC20(silo0, receiver);
    totalSupplyMoreThanBalanceERC20(shareProtectedCollateralToken0, receiver);
    totalSupplyMoreThanBalanceERC20(token0, e.msg.sender);
    totalSupplyMoreThanBalanceERC20(silo0, e.msg.sender);
    totalSupplyMoreThanBalanceERC20(shareProtectedCollateralToken0, e.msg.sender);

    require totalSupplyByToken[token0] >= require_uint256(
        silo0.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Protected)) +
        silo0.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Collateral)) +
        balanceByToken[token0][receiver]
    );

    uint256 shares;
    uint256 sharesAttempt1;
    uint256 sharesAttempt2;
    require shares == sharesAttempt1 + sharesAttempt2;  // TODO: Prove without this line!

    mathint balanceTokenBefore = balanceByToken[token0][e.msg.sender];
    mathint balanceCollateralBefore = balanceByToken[silo0][receiver];
    mathint balanceProtectedCollateralBefore = balanceByToken[shareProtectedCollateralToken0][receiver];

    storage init = lastStorage;
    ISilo.CollateralType anyType;

    mint(e, shares, receiver, anyType);
    mathint balanceTokenAfterSum = balanceByToken[token0][e.msg.sender];
    mathint balanceCollateralAfterSum = balanceByToken[silo0][receiver];
    mathint balanceProtectedCollateralAfterSum = balanceByToken[shareProtectedCollateralToken0][receiver];

    mint(e, sharesAttempt1, receiver, anyType) at init;
    mathint balanceTokenAfter1 = balanceByToken[token0][e.msg.sender];
    mathint balanceCollateralAfter1 = balanceByToken[silo0][receiver];
    mathint balanceProtectedCollateralAfter1 = balanceByToken[shareProtectedCollateralToken0][receiver];

    mint(e, sharesAttempt2, receiver, anyType);
    mathint balanceTokenAfter1_2 = balanceByToken[token0][e.msg.sender];
    mathint balanceCollateralAfter1_2 = balanceByToken[silo0][receiver];
    mathint balanceProtectedCollateralAfter1_2 = balanceByToken[shareProtectedCollateralToken0][receiver];

    mathint diffTokenCombined = balanceTokenAfterSum - balanceTokenBefore;
    mathint diffCollateraCombined = balanceCollateralAfterSum - balanceCollateralBefore;
    mathint diffProtectedCombined = balanceProtectedCollateralAfterSum - balanceProtectedCollateralBefore;

    mathint diffTokenBrokenUp = balanceTokenAfter1_2 - balanceTokenBefore;
    mathint diffCollateraBrokenUp = balanceCollateralAfter1_2 - balanceCollateralBefore;
    mathint diffProtectedBrokenUp = balanceProtectedCollateralAfter1_2 - balanceProtectedCollateralBefore;

    assert !(diffTokenBrokenUp >= diffTokenCombined  && 
            (diffCollateraBrokenUp > diffCollateraCombined + 1 ||
            diffProtectedBrokenUp > diffProtectedCombined + 1));

    assert !(diffCollateraBrokenUp >= diffCollateraCombined && 
            diffProtectedBrokenUp >= diffProtectedCombined && 
            diffTokenBrokenUp > diffTokenCombined);

}

/// @title User should not profit by depositing and immediately redeeming
rule HLP_DepositRedeemNotProfitable(env e, address receiver, uint256 assets)
{
    completeSiloSetupEnv(e);
    setupTokensSharesConfig();

    totalSupplyMoreThanBalanceERC20(token0, receiver);
    totalSupplyMoreThanBalanceERC20(token0, e.msg.sender);
    totalSupplyMoreThanBalanceERC20(silo0, receiver);
    totalSupplyMoreThanBalanceERC20(silo0, e.msg.sender);
    require totalSupplyByToken[token0] >= require_uint256(
        silo0.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Protected)) +
        silo0.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Collateral)) +
        balanceByToken[token0][receiver]
    );

    mathint balanceCollateralBefore = balanceByToken[silo0][receiver];
    mathint balanceTokenBefore = balanceByToken[token0][e.msg.sender];

    // TODO: This requirement is necessary due to a bug in the code, unless we
    // proved an invariant: "zero shares implies zero assets"
    require totalSupplyByToken[silo0] > 0;

    // TODO: This deposit is the same as depositing `CollateralType.Collateral`
    //       What about depositing `CollateralType.Protected`?
    mathint sharesM1 = deposit(e, assets, receiver);
    mathint balanceCollateralM1 = balanceByToken[silo0][receiver];
    mathint balanceTokenM1 = balanceByToken[token0][e.msg.sender];

    uint256 shares;
    mathint assetsR = redeem(e, shares, e.msg.sender, receiver);
    mathint balanceCollateralR = balanceByToken[silo0][receiver];
    mathint balanceTokenR = balanceByToken[token0][e.msg.sender];

    assert balanceCollateralR > balanceCollateralBefore => balanceTokenR < balanceTokenBefore;
    assert balanceTokenR > balanceTokenBefore => balanceCollateralR < balanceCollateralBefore;
}
