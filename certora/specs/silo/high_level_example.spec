
import "../_simplifications/priceOracle.spec";
import "../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";
import "../erc20cvl.spec";
import "_common/SiloConfigSummarizations.spec";

using Silo0 as silo0;
using Silo1 as silo1;

using Token0 as token0;
using ShareDebtToken0 as shareDebtToken0;
using ShareCollateralToken0 as shareCollateralToken0;
using ShareProtectedCollateralToken0 as shareProtectedCollateralToken0;

using Token1 as token1;
using ShareDebtToken1 as shareDebtToken1;
using ShareCollateralToken1 as shareCollateralToken1;
using ShareProtectedCollateralToken1 as shareProtectedCollateralToken1;

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
    // NOTE: Summarizing `_afterTokenTransfer` as `CONSTANT` is an under-approximation!
    function _._afterTokenTransfer(address,address,uint256) internal => CONSTANT;

    // ---- `Actions` ----------------------------------------------------------
    function Actions._hookCallBeforeBorrow(ISilo.BorrowArgs memory, uint256) internal => NONDET;

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




// checks that two mints never give better tradeoff than one
// violated. E.g. mint(13) costs 4, mint(4);mint(10) costs 1+3=4
// https://prover.certora.com/output/6893/30faf353b80b4e41bd8de18b7ce080f7/?anonymousKey=a9260fb2c1753b137aae9218621c8267f88b0e0d
rule HLP_mint_breakingUpNotBeneficial_full(env e, address receiver)
{
    completeSiloSetupEnv(e);
    // totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalanceERC20(token0, receiver);
    totalSupplyMoreThanBalanceERC20(shareCollateralToken0, receiver);
    totalSupplyMoreThanBalanceERC20(shareProtectedCollateralToken0, receiver);
    totalSupplyMoreThanBalanceERC20(token0, e.msg.sender);
    totalSupplyMoreThanBalanceERC20(shareCollateralToken0, e.msg.sender);
    totalSupplyMoreThanBalanceERC20(shareProtectedCollateralToken0, e.msg.sender);
    require totalSupplyByToken[token0] >= require_uint256(
        silo0.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Protected)) +
        silo0.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Collateral)) +
        balanceByToken[token0][receiver]
    );

    require config() == siloConfig;
    require silo1.config() == siloConfig;  // TODO: same config for both?

    uint256 shares;
    uint256 sharesAttempt1;
    uint256 sharesAttempt2;
    require shares == sharesAttempt1 + sharesAttempt2;

    mathint balanceTokenBefore = balanceByToken[token0][e.msg.sender];
    mathint balanceCollateralBefore = balanceByToken[shareCollateralToken0][receiver];
    mathint balanceProtectedCollateralBefore = balanceByToken[shareProtectedCollateralToken0][receiver];

    storage init = lastStorage;
    ISilo.CollateralType anyType;

    mint(e, shares, receiver, anyType);
    mathint balanceTokenAfterSum = balanceByToken[token0][e.msg.sender];
    mathint balanceCollateralAfterSum = balanceByToken[shareCollateralToken0][receiver];
    mathint balanceProtectedCollateralAfterSum = balanceByToken[shareProtectedCollateralToken0][receiver];

    mint(e, sharesAttempt1, receiver, anyType) at init;
    mathint balanceTokenAfter1 = balanceByToken[token0][e.msg.sender];
    mathint balanceCollateralAfter1 = balanceByToken[shareCollateralToken0][receiver];
    mathint balanceProtectedCollateralAfter1 = balanceByToken[shareProtectedCollateralToken0][receiver];

    mint(e, sharesAttempt2, receiver, anyType);
    mathint balanceTokenAfter1_2 = balanceByToken[token0][e.msg.sender];
    mathint balanceCollateralAfter1_2 = balanceByToken[shareCollateralToken0][receiver];
    mathint balanceProtectedCollateralAfter1_2 = balanceByToken[shareProtectedCollateralToken0][receiver];

    mathint diffTokenCombined = balanceTokenAfterSum - balanceTokenBefore;
    mathint diffCollateraCombined = balanceCollateralAfterSum - balanceCollateralBefore;
    mathint diffProtectedCombined = balanceProtectedCollateralAfterSum - balanceProtectedCollateralBefore;

    mathint diffTokenBrokenUp = balanceTokenAfter1_2 - balanceTokenBefore;
    mathint diffCollateraBrokenUp = balanceCollateralAfter1_2 - balanceCollateralBefore;
    mathint diffProtectedBrokenUp = balanceProtectedCollateralAfter1_2 - balanceProtectedCollateralBefore;

    assert !(diffTokenBrokenUp >= diffTokenCombined  && 
            (diffCollateraBrokenUp > diffCollateraCombined + 1 || diffProtectedBrokenUp > diffProtectedCombined + 1));

    assert !(diffCollateraBrokenUp >= diffCollateraCombined && 
            diffProtectedBrokenUp >= diffProtectedCombined && 
            diffTokenBrokenUp > diffTokenCombined);

}

/*
// TODO: copied from `certora/specs/silo/_common/CompleteSiloSetup.spec`
function totalSupplyMoreThanBalance(address receiver)
{
    require receiver != currentContract;
    require token0.totalSupply() >= require_uint256(token0.balanceOf(receiver) + token0.balanceOf(currentContract));
    require shareProtectedCollateralToken0.totalSupply() >= require_uint256(shareProtectedCollateralToken0.balanceOf(receiver) + shareProtectedCollateralToken0.balanceOf(currentContract));
    require shareDebtToken0.totalSupply() >= require_uint256(shareDebtToken0.balanceOf(receiver) + shareDebtToken0.balanceOf(currentContract));
    require shareCollateralToken0.totalSupply() >= require_uint256(shareCollateralToken0.balanceOf(receiver) + shareCollateralToken0.balanceOf(currentContract));
    require token1.totalSupply() >= require_uint256(token1.balanceOf(receiver) + token1.balanceOf(currentContract));
    require shareProtectedCollateralToken1.totalSupply() >= require_uint256(shareProtectedCollateralToken1.balanceOf(receiver) + shareProtectedCollateralToken1.balanceOf(currentContract));
    require shareDebtToken1.totalSupply() >= require_uint256(shareDebtToken1.balanceOf(receiver) + shareDebtToken1.balanceOf(currentContract));
    require shareCollateralToken1.totalSupply() >= require_uint256(shareCollateralToken1.balanceOf(receiver) + shareCollateralToken1.balanceOf(currentContract));

    // otherwise there's an overflow in "unchecked" in SiloSolvencyLib.getPositionValues 
    require token0.totalSupply() >= require_uint256(
            silo0.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Protected)) +
            silo0.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Collateral)) +
            token0.balanceOf(receiver)
            );
    require token1.totalSupply() >= require_uint256(
            silo1.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Protected)) +
            silo1.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Collateral)) +
            token1.balanceOf(receiver)
            );

    // if user has debt he must have collateral in the other silo
    require shareDebtToken0.balanceOf(receiver) > 0 => (
            shareCollateralToken1.balanceOf(receiver) > 0 ||
            shareProtectedCollateralToken1.balanceOf(receiver) > 0);
    require shareDebtToken1.balanceOf(receiver) > 0 => (
            shareCollateralToken0.balanceOf(receiver) > 0 ||
            shareProtectedCollateralToken0.balanceOf(receiver) > 0);
}
*/

// TODO: copied from `certora/specs/silo/_common/CompleteSiloSetup.spec`
function doesntHaveCollateralAsWellAsDebt(address user)
{
    require !(  //cannot have collateral AND debt on silo0
            (balanceByToken[shareCollateralToken0][user] > 0 || 
             balanceByToken[shareProtectedCollateralToken0][user] > 0) &&
            balanceByToken[shareDebtToken0][user] > 0);

    require !(  //cannot have collateral AND debt on silo1
            (balanceByToken[shareCollateralToken1][user] > 0 || 
             balanceByToken[shareProtectedCollateralToken1][user] > 0) &&
            balanceByToken[shareDebtToken1][user] > 0);
}

// TODO: copied from `certora/specs/silo/_common/CompleteSiloSetup.spec`
function completeSiloSetupAddress(address sender)
{
    require sender != shareCollateralToken0;
    require sender != shareDebtToken0;
    require sender != shareProtectedCollateralToken0;
    require sender != shareProtectedCollateralToken1;
    require sender != shareDebtToken1;
    require sender != shareCollateralToken1;
    // require sender != siloConfig;  TODO: removed for re-setup
    require sender != currentContract;  /// Silo0
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
            totalSupplyByToken[shareCollateralToken0] == 0 <=>
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
            totalSupplyByToken[shareCollateralToken1] == 0 <=>
            silo1.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Collateral)) == 0
            );

}

// TODO: copied from `certora/specs/silo/_common/CompleteSiloSetup.spec`
function completeSiloSetupEnv(env e) {

    completeSiloSetupAddress(e.msg.sender);
    // we can not have block.timestamp less than interestRateTimestamp
    require e.block.timestamp < (1 << 64);
    require require_uint64(e.block.timestamp) >= silo0.getSiloDataInterestRateTimestamp(e);
    require require_uint64(e.block.timestamp) >= silo1.getSiloDataInterestRateTimestamp(e);
}
/*
// holds
// https://prover.certora.com/output/6893/2ff8676c6e1142f8ae409ca94991b06b/?anonymousKey=22d2387bfb082e9c8d098dc21bdc15b9b38702c2
rule HLP_DepositRedeemNotProfitable(env e, address receiver)
{
    require config() == siloConfig;
    require silo1.config() == siloConfig;  // TODO: same config for both?

    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);

    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint balanceTokenBefore = token0.balanceOf(e.msg.sender);

    // TODO: This requirement is necessary due to a bug in the code, unless we
    // proved an invariant: "zero shares implies zero assets"
    require shareCollateralToken0.totalSupply(e) > 0;

    uint256 assets;
    // TODO: This deposit is the same as depositing `CollateralType.Collateral`
    //       What about depositing `CollateralType.Protected`?
    mathint sharesM1 = deposit(e, assets, receiver);  // TODO: what about depositing to other asset types?
    mathint balanceCollateralM1 = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenM1 = token0.balanceOf(e.msg.sender);    

    uint256 shares;
    mathint assetsR = redeem(e, shares, e.msg.sender, receiver);
    mathint balanceCollateralR = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenR = token0.balanceOf(e.msg.sender);    

    assert balanceCollateralR > balanceCollateralBefore => balanceTokenR < balanceTokenBefore;
    assert balanceTokenR > balanceTokenBefore => balanceCollateralR < balanceCollateralBefore;
}
*/

rule HLP_DepositRedeemNotProfitableFixed(env e, address receiver)
{
    require config() == siloConfig;
    require silo1.config() == siloConfig;  // TODO: same config for both?

    completeSiloSetupEnv(e);
    //totalSupplyMoreThanBalance(receiver);
    //totalSupplyMoreThanBalance(e.msg.sender);
    totalSupplyMoreThanBalanceERC20(token0, receiver);
    totalSupplyMoreThanBalanceERC20(token0, e.msg.sender);
    totalSupplyMoreThanBalanceERC20(shareCollateralToken0, receiver);
    totalSupplyMoreThanBalanceERC20(shareCollateralToken0, e.msg.sender);
    require totalSupplyByToken[token0] >= require_uint256(
        silo0.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Protected)) +
        silo0.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Collateral)) +
        balanceByToken[token0][receiver]
    );

    mathint balanceCollateralBefore = balanceByToken[shareCollateralToken0][receiver];
    mathint balanceTokenBefore = balanceByToken[token0][e.msg.sender];

    // TODO: This requirement is necessary due to a bug in the code, unless we
    // proved an invariant: "zero shares implies zero assets"
    require totalSupplyByToken[shareCollateralToken0] > 0;

    uint256 assets;
    // TODO: This deposit is the same as depositing `CollateralType.Collateral`
    //       What about depositing `CollateralType.Protected`?
    mathint sharesM1 = deposit(e, assets, receiver);  // TODO: what about depositing to other asset types?
    mathint balanceCollateralM1 = balanceByToken[shareCollateralToken0][receiver];
    mathint balanceTokenM1 = balanceByToken[token0][e.msg.sender];

    uint256 shares;
    mathint assetsR = redeem(e, shares, e.msg.sender, receiver);
    mathint balanceCollateralR = balanceByToken[shareCollateralToken0][receiver];
    mathint balanceTokenR = balanceByToken[token0][e.msg.sender];

    assert balanceCollateralR > balanceCollateralBefore => balanceTokenR < balanceTokenBefore;
    assert balanceTokenR > balanceTokenBefore => balanceCollateralR < balanceCollateralBefore;
}