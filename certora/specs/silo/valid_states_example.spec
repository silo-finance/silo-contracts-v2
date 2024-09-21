/* SiloMethods.spec */
using Silo0 as silo0;  // NOTE: Alias for `currentContract` in this example
using Silo1 as silo1;  // NOTE: This is redundant in this example

using SiloConfig as siloConfig;

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
    // Getters
    function Silo0.getTotalAssetsStorage(uint256) external returns(uint256) envfree;
    function Silo1.getTotalAssetsStorage(uint256) external returns(uint256) envfree;
    
    function Silo0.config() external returns (address) envfree;
    function Silo1.config() external returns (address) envfree;

    function Silo0.getTotalAssetsStorage(uint256) external returns (uint256) envfree;
    function Silo1.getTotalAssetsStorage(uint256) external returns (uint256) envfree;

    function _.getTotalAssetsStorage(uint256) external => DISPATCHER(true);

    // Harness
    function Silo0.getSiloDataInterestRateTimestamp() external returns(uint64) envfree;
    function Silo1.getSiloDataInterestRateTimestamp() external returns(uint64) envfree;

    function Silo0.getSiloDataDaoAndDeployerRevenue() external returns(uint192) envfree;
    function Silo1.getSiloDataDaoAndDeployerRevenue() external returns(uint192) envfree;

    // Dispatcher
    function _.accrueInterest() external => DISPATCHER(true);

    // ---- `SiloConfig` -------------------------------------------------------
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
    function _.getCollateralAndProtectedTotalsStorage() external  => DISPATCHER(true);

    // `CrossReentrancyGuard`
    function _.turnOnReentrancyProtection() external => DISPATCHER(true);
    function _.turnOffReentrancyProtection() external => DISPATCHER(true);

    // ---- `IInterestRateModel` -----------------------------------------------
    // Since `getCompoundInterestRateAndUpdate` is not view, this is not strictly sound.
    function _.getCompoundInterestRateAndUpdate(
        uint256 _collateralAssets,
        uint256 _debtAssets,
        uint256 _interestRateTimestamp
    ) external => NONDET;

    // ---- `ISiloOracle` ------------------------------------------------------
    // NOTE: Since `beforeQuote` is not a view function, strictly speaking this is unsound.
    function _.beforeQuote(address) external => NONDET;

    // NOTE: Summarizes as fixed price of 1 -- an under-approximation.
    function _.quote(
        uint256 _baseAmount,
        address _baseToken
    ) external  => price_is_one(_baseAmount, _baseToken) expect uint256;

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
    
    // ---- `SiloSolvencyLib` --------------------------------------------------
    // NOTE: Simplifies the solvency calculation, probably not an under-approximation
    function SiloSolvencyLib.isSolvent(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower,
        ISilo.AccrueInterestInMemory _accrueInMemory
    ) internal returns (bool) => simplified_solvent(_debtConfig, _borrower);
    
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

    // ---- Tokens -------------------------------------------------------------
    // Specific tokens
    function Token0.balanceOf(address) external returns (uint256) envfree;
    function ShareDebtToken0.balanceOf(address) external returns (uint256) envfree;
    function ShareCollateralToken0.balanceOf(address) external returns (uint256) envfree;
    function ShareProtectedCollateralToken0.balanceOf(address) external returns (uint256) envfree;
    
    function Token0.totalSupply() external returns (uint256) envfree;
    function ShareDebtToken0.totalSupply() external returns (uint256) envfree;
    function ShareCollateralToken0.totalSupply() external returns (uint256) envfree;
    function ShareProtectedCollateralToken0.totalSupply() external returns (uint256) envfree;
    
    function Token1.balanceOf(address) external returns (uint256) envfree;
    function ShareDebtToken1.balanceOf(address) external returns (uint256) envfree;
    function ShareCollateralToken1.balanceOf(address) external returns (uint256) envfree;
    function ShareProtectedCollateralToken1.balanceOf(address) external returns (uint256) envfree;
    
    function Token1.totalSupply() external returns (uint256) envfree;
    function ShareDebtToken1.totalSupply() external returns (uint256) envfree;
    function ShareCollateralToken1.totalSupply() external returns (uint256) envfree;
    function ShareProtectedCollateralToken1.totalSupply() external returns (uint256) envfree;

    // The functions `name` and `symbol` are deleted since they cause memory partitioning
    // problems.
    function _.name() external => PER_CALLEE_CONSTANT DELETE;
    function _.symbol() external => PER_CALLEE_CONSTANT DELETE;

    // Using `DISPATCHER` for calls like `IShareToken(debtShareToken).balanceOf(borrower)`
    function _.decimals() external => DISPATCHER(true);
    function _.totalSupply() external => DISPATCHER(true);
    function _.balanceOf(address) external => DISPATCHER(true);
    function _.allowance(address,address) external => DISPATCHER(true);
    function _.approve(address,uint256) external => DISPATCHER(true);
    function _.mint(address,address,uint256) external => DISPATCHER(true);
    function _.burn(address,address,uint256) external => DISPATCHER(true);
    function _.transfer(address,uint256) external => DISPATCHER(true);
    function _.transferFrom(address,address,uint256) external => DISPATCHER(true);

    // `IShareToken`
    function _.balanceOfAndTotalSupply(address) external => DISPATCHER(true);
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

/// @title Setup a reasonable `env` time
function setupSiloEnvTimestamp(env e) {
    // We can not have `block.timestamp` less than `interestRateTimestamp`
    require e.block.timestamp < (1 << 64);
    require require_uint64(e.block.timestamp) >= silo0.getSiloDataInterestRateTimestamp(e);
    require require_uint64(e.block.timestamp) >= silo1.getSiloDataInterestRateTimestamp(e);
}


/// @title Set an address that is different from all contracts in the scene
function siloSetupAddress(address sender) {
    require sender != shareCollateralToken0;
    require sender != shareDebtToken0;
    require sender != shareProtectedCollateralToken0;
    require sender != shareProtectedCollateralToken1;
    require sender != shareDebtToken1;
    require sender != shareCollateralToken1;
    require sender != siloConfig;
    require sender != currentContract;  // `Silo0`
    require sender != silo1;
    require sender != token0;
    require sender != token1;
}

/// @title Prevents a user with both collateral and debt in the same silo
function doesntHaveCollateralAsWellAsDebt(address user) {
    // Cannot have collateral AND debt on `silo0`
    require !(
        (
            shareCollateralToken0.balanceOf(user) > 0 || 
            shareProtectedCollateralToken0.balanceOf(user) > 0
        ) &&
        shareDebtToken0.balanceOf(user) > 0
    );

    // Cannot have collateral AND debt on `silo1`
    require !(
        (
            shareCollateralToken1.balanceOf(user) > 0 || 
            shareProtectedCollateralToken1.balanceOf(user) > 0
        ) &&
        shareDebtToken1.balanceOf(user) > 0
    );
}


/// @title Requires that no shares is the same as no tokens
/// @notice When this doesn't hold  (e.g. zero shares by some assets) the first depositor
/// can get all the assets.
/// TODO: These should be proven using invariants!
function zeroSharesIsZeroAssets() {
    require (
        shareDebtToken0.totalSupply() == 0 <=> 
        silo0.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Debt)) == 0
    );
    require (
        shareProtectedCollateralToken0.totalSupply() == 0 <=>
        silo0.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Protected)) == 0
    );
    require (
        shareCollateralToken0.totalSupply() == 0 <=>
        silo0.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Collateral)) == 0
    );

    require (
        shareDebtToken1.totalSupply() == 0 <=>
        silo1.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Debt)) == 0
    );
    require (
        shareProtectedCollateralToken1.totalSupply() == 0 <=>
        silo1.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Protected)) == 0
    );
    require (
        shareCollateralToken1.totalSupply() == 0 <=>
        silo1.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Collateral)) == 0
    );
}


/// @title Sets up the silos with the same config
function setupConfig() {
    require silo0.config() == siloConfig;
    require silo1.config() == siloConfig;
}


// ---- Rules ------------------------------------------------------------------

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "VS_Silo_interestRateTimestamp_daoAndDeployerRevenue" \
    --rule "VS_Silo_interestRateTimestamp_daoAndDeployerRevenue" \
    --verify "Silo0:certora/specs/silo/valid-state/ValidStateSilo0.spec"
*/
// TODO: fix property doc (renaming)
// TODO: Is this a correct way to prove the property? Seems weak
rule VS_Silo_interestRateTimestamp_daoAndDeployerRevenue(
    env e,
    method f,
    calldataarg args
) filtered {
    f -> (
        !f.isView &&
        // Only flash loan can increase rates
        f.selector != sig:flashLoan(address,address,uint256,bytes).selector &&
        // TODO: Contains a `delegatecall`, can it be filtered out?
        f.selector != sig:callOnBehalfOfSilo(address,uint256,ISilo.CallType,bytes).selector &&
        // `withdrawFees` reverts if earned fees are zero, hence is vacuous
        f.selector != sig:withdrawFees().selector
    )
} {
    // Setup
    setupSiloEnvTimestamp(e);
    siloSetupAddress(e.msg.sender);

    // Preconditions - time-stamp and fees are zero
    require getSiloDataInterestRateTimestamp() == 0;
    require getSiloDataDaoAndDeployerRevenue() == 0;

    f(e, args);

    mathint feesAfter = getSiloDataDaoAndDeployerRevenue();

    assert (
        getSiloDataInterestRateTimestamp() == 0 => feesAfter == 0,
        "Interest rate timestamp 0 => dao and deployer fees 0"
    );
}

/**
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "VS_Silo_totalBorrowAmount" \
    --rule "VS_Silo_totalBorrowAmount" \
    --verify "Silo0:certora/specs/silo/valid-state/ValidStateSilo0.spec"
*/
// TODO: Why not as an invariant? This seems weak.
rule VS_Silo_totalBorrowAmount(env e, method f, calldataarg args) filtered {
    f -> (
        !f.isView &&
        // TODO: Contains a `delegatecall`, is it sound to filter out?
        f.selector != sig:callOnBehalfOfSilo(address,uint256,ISilo.CallType,bytes).selector &&
        // All functions that call `SiloERC4626Lib.withdraw` are vacuous, since it requires
        // assets or shares to be non-zero.
        f.selector != sig:withdraw(uint256,address,address).selector &&
        f.selector != sig:withdraw(uint256,address,address,ISilo.CollateralType).selector &&
        f.selector != sig:redeem(uint256,address,address).selector &&
        f.selector != sig:redeem(uint256,address,address,ISilo.CollateralType).selector
    )
} {
    setupSiloEnvTimestamp(e);
    siloSetupAddress(e.msg.sender);

    require silo0.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Debt)) == 0;
    require silo0.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Collateral)) == 0;

    f(e, args);

    assert (
        silo0.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Debt)) != 0 =>
        silo0.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Collateral)) != 0,
        "Total debt assets != 0 => total collateral assets != 0"
    );
}


invariant VS_Silo_totalBorrowAmount_invariant()
    silo0.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Debt)) != 0 => (
        silo0.getTotalAssetsStorage(require_uint256(ISilo.AssetType.Collateral)) != 0
    )
    filtered {
        f -> (
            // TODO: Contains a `delegatecall`, can it be filtered out?
            f.selector != sig:callOnBehalfOfSilo(address,uint256,ISilo.CallType,bytes).selector
        )
    }
    {
        preserved with (env e) {
            setupSiloEnvTimestamp(e);
            siloSetupAddress(e.msg.sender);
        }
        preserved leverageSameAsset(
            uint256 _depositAssets,
            uint256 _borrowAssets,
            address _borrower,
            ISilo.CollateralType _collateralType
        ) with (env e) {
            setupSiloEnvTimestamp(e);
            siloSetupAddress(e.msg.sender);
            siloSetupAddress(_borrower);
            zeroSharesIsZeroAssets();
        }
    }
