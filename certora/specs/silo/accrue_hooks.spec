/* This spec shows that only `_accrueInterestForAsset` can change certain variables,
 * such as interest rate time stamp. We do this by disabling this function and showing
 * these variables are unchanghed.
 *
 * NOTE: This setup is for a single silo - `Silo0`.
 */

import "../setup/single_silo_tokens_requirements.spec";
import "../setup/summaries/silo0_summaries.spec";
import "../setup/summaries/config_for_one_in_cvl.spec";
//import "../setup/summaries/siloconfig_dispatchers.spec";
import "../setup/summaries/safe-approximations.spec";

methods {
    // ---- `SiloHarness` ------------------------------------------------------
    function getSiloStorage() external returns (uint192, uint64, uint256, uint256, uint256) envfree;

    // ---- `Silo` -------------------------------------------------------------
    function Silo._accrueInterestForAsset(
        address _interestRateModel,
        uint256 _daoFee,
        uint256 _deployerFee
    ) internal returns (uint256) with (env e) => CVLAccrueInterestForAsset(
        e,
        calledContract,
        _interestRateModel,
        _daoFee,
        _deployerFee
    );

    // ---- `ShareToken` -------------------------------------------------------
    function Silo0.balanceOf(address) external returns (uint256) envfree;
    function ShareDebtToken0.balanceOf(address) external returns (uint256) envfree;
    function ShareProtectedCollateralToken0.balanceOf(address) external returns (uint256) envfree;

    function _.synchronizeHooks(uint24,uint24) external => DISPATCHER(true);

    // ---- `SiloConfig` -------------------------------------------------------
    // `envfree`
    function SiloConfig.accrueInterestForSilo(address) external envfree;
    function SiloConfig.getCollateralShareTokenAndAsset(
        address,
        ISilo.CollateralType
    ) external returns (address, address) envfree;

    // Dispatcher
    function _.accrueInterestForSilo(address) external => DISPATCHER(true);
    function _.accrueInterestForBothSilos() external => DISPATCHER(true);
    function _.getConfigsForWithdraw(address,address) external => DISPATCHER(true);
    function _.getConfigsForBorrow(address) external  => DISPATCHER(true);
    function _.getConfigsForSolvency(address) external  => DISPATCHER(true);
    function _.setThisSiloAsCollateralSilo(address) external  => DISPATCHER(true);
    function _.setOtherSiloAsCollateralSilo(address) external  => DISPATCHER(true);
    function _.getConfig(address) external  => DISPATCHER(true);
    function _.borrowerCollateralSilo(address) external  => DISPATCHER(true);
    function _.onDebtTransfer(address,address) external  => DISPATCHER(true);

    // `CrossReentrancyGuard`
    function _.turnOnReentrancyProtection() external => DISPATCHER(true);
    function _.turnOffReentrancyProtection() external => DISPATCHER(true);

    // ---- `ISiloOracle` ------------------------------------------------------
    // NOTE: Since `beforeQuote` is not a view function, strictly speaking this is unsound.
    function _.beforeQuote(address) external => NONDET DELETE;

    // ---- `IInterestRateModel` -----------------------------------------------
    // Since `getCompoundInterestRateAndUpdate` is not *pure*, this is not strictly sound.
    function _.getCompoundInterestRateAndUpdate(
        uint256 _collateralAssets,
        uint256 _debtAssets,
        uint256 _interestRateTimestamp
    ) external =>  CVLGetCompoundInterestRate(
        _collateralAssets,
        _debtAssets,
        _interestRateTimestamp
    ) expect (uint256);
}

// ---- Functions and ghosts ---------------------------------------------------

ghost mapping(address => mathint) numAccrueCalls;

ghost uint192 daoAndDeployerRevenueAt;
ghost uint64 interestRateTimestampAt;

// Ghosts to check if balance changed before `_accrueInterestForAsset` was called
ghost bool isAccrueCalledBefore;  // True if `_accrueInterestForAsset` was called before
ghost bool isAccrueCalled;  // True if `_accrueInterestForAsset` was called
ghost address user;  // Arbitrary user

ghost uint256 userSilo0BalancePre;
ghost bool isUserSilo0BalanceChanged;

ghost uint256 userDebt0BalancePre;
ghost bool isUserDebt0BalanceChanged;

ghost uint256 userProtected0BalancePre;
ghost bool isUserProtected0BalanceChanged;


/// @title Summary of `_accrueInterestForAsset` which disables any side affects
function CVLAccrueInterestForAsset(
    env e,
    address contract,
    address _interestRateModel,
    uint256 _daoFee,
    uint256 _deployerFee
) returns uint256 {
    isAccrueCalled = true;
    (
        daoAndDeployerRevenueAt,
        interestRateTimestampAt,
        _, _, _
    ) = getSiloStorage();
    numAccrueCalls[contract] = numAccrueCalls[contract] + 1;

    // Check if balances changed before first call
    if (!isAccrueCalledBefore) {
        isAccrueCalledBefore = true;
        isUserSilo0BalanceChanged = silo0.balanceOf(user) != userSilo0BalancePre;
        isUserDebt0BalanceChanged = shareDebtToken0.balanceOf(user) != userDebt0BalancePre;
        isUserProtected0BalanceChanged = (
            shareProtectedCollateralToken0.balanceOf(user) != userProtected0BalancePre
        );
    }

    // Non-deterministic return value.
    uint256 ret;
    return ret;
}


ghost mapping(uint256 => mapping(uint256 => mapping(uint256 => uint256))) interestGhost;

/// @title An arbitrary (pure) function for the interest rate
function CVLGetCompoundInterestRate(
    uint256 _collateralAssets,
    uint256 _debtAssets,
    uint256 _interestRateTimestamp
) returns uint256 {
    return interestGhost[_collateralAssets][_debtAssets][_interestRateTimestamp];
}


/// @title Methods that will be used in parametric rules (e.g. non-view methods)
definition isParametricMethod(method f) returns bool = (
    !f.isView &&
    // `callOnBehalfOfSilo` uses a `delegatecall`
    f.selector != sig:callOnBehalfOfSilo(address,uint256,ISilo.CallType,bytes).selector &&
    // TODO: `decimals` fails sanity
    f.selector != sig:decimals().selector &&
    // NOTE: Inside `flashLoan` can call any other method, so it should be added to all
    // the definitions here. But in order to save time, we simply skip it.
    f.selector != sig:flashLoan(address,address,uint256,bytes).selector
);


/// @title Methods which change balances but do not accrue interest in storage
definition isTranferNonAccruing(method f) returns bool = (
    // The call to `_accrueInterestForAsset` in `transfer` is done after the transfer
    // using `_afterTokenTransfer` in debt token (and there it is accrued in memory).
    f.selector == sig:transfer(address,uint256).selector ||
    f.selector == sig:transferFrom(address,address,uint256).selector ||
    f.selector == sig:shareDebtToken0.transfer(address,uint256).selector ||
    f.selector == sig:shareDebtToken0.transferFrom(address,address,uint256).selector ||
    f.selector == sig:shareProtectedCollateralToken0.transfer(address,uint256).selector ||
    f.selector == sig:shareProtectedCollateralToken0.transferFrom(address,address,uint256).selector
);


// ---- Hooks and ghosts -------------------------------------------------------
// This hooks notes if account values change before calls to `_accrueInterestForAsset`.
// NOTE: we cannot hook into balance changes for `ShareToken` contracts since these use
// unstructured storage pattern.

ghost bool tokenAccountChangedBefore;

hook Sstore token0._balances[KEY address a] uint new_val (uint old_val) {
    if (numAccrueCalls[silo0] == 0) {
        tokenAccountChangedBefore = true;
    }
}

// ---- Rules ------------------------------------------------------------------

/// @title Only `_accrueInterestForAsset` can change revenue and assets variables
/// @notice This is done by disabling `_accrueInterestForAsset` and showing that these
/// variables do not change.
/// @notice We prove here 3 things:
/// 1. There are no changes before calling `_accrueInterestForAsset`.
/// 2. Only changes are possible if `_accrueInterestForAsset` is called.
/// 3. At most one call to `_accrueInterestForAsset` per method.
rule onlyAccrueCanChangeVars(method f) filtered {
    f -> isParametricMethod(f)
} {
    numAccrueCalls[silo0] = 0;

    uint192 daoAndDeployerRevenuePre;
    uint64 interestRateTimestampPre;
    (
        daoAndDeployerRevenuePre,
        interestRateTimestampPre,
        _, _, _
    ) = getSiloStorage();

    env e;
    calldataarg args;
    f(e, args);

    uint192 daoAndDeployerRevenuePost;
    uint64 interestRateTimestampPost;
    (
        daoAndDeployerRevenuePost,
        interestRateTimestampPost,
        _, _, _
    ) = getSiloStorage();

    assert (
        f.selector != sig:withdrawFees().selector => (
            daoAndDeployerRevenuePre == daoAndDeployerRevenuePost &&
            interestRateTimestampPre == interestRateTimestampPost
        ),
        "Only _accrueInterestForAsset and withdrawFees can change revenue variables"
    );
    assert (numAccrueCalls[silo0] <= 2, "At most two _accrueInterestForAsset call");
    assert (
        numAccrueCalls[silo0] > 0 => (
            daoAndDeployerRevenuePre == daoAndDeployerRevenueAt &&
            interestRateTimestampPre == interestRateTimestampAt
        ),
        "No variable changes before _accrueInterestForAsset call"
    );
}


/// @title User's accounts are not changed before call to `_accrueInterestForAsset`
rule noAccountChangesBeforeAccrue(method f) filtered {
    f -> isParametricMethod(f) && !isTranferNonAccruing(f)
} {
    numAccrueCalls[silo0] = 0;

    isAccrueCalledBefore = false;
    isUserSilo0BalanceChanged = false;
    isUserDebt0BalanceChanged = false;
    isUserProtected0BalanceChanged = false;
    tokenAccountChangedBefore = false;

    userSilo0BalancePre = silo0.balanceOf(user);
    userDebt0BalancePre = shareDebtToken0.balanceOf(user);
    userProtected0BalancePre = shareProtectedCollateralToken0.balanceOf(user);

    env e;
    calldataarg args;
    f(e, args);

    assert (
        !tokenAccountChangedBefore &&
        !isUserSilo0BalanceChanged &&
        !isUserDebt0BalanceChanged &&
        !isUserProtected0BalanceChanged,
        "Accounts do not change before accruing revenue"
    );
}
