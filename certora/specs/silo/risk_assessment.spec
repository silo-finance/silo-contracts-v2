/* Valid states example spec */
using Silo0 as silo0;  // NOTE: Alias for `currentContract` in this example
using Silo1 as silo1;  // NOTE: This is redundant in this example

using SiloConfig as siloConfig;

using Token0 as token0;
using ShareDebtToken0 as shareDebtToken0;
using ShareProtectedCollateralToken0 as shareProtectedCollateralToken0;

using Token1 as token1;
using ShareDebtToken1 as shareDebtToken1;
using ShareProtectedCollateralToken1 as shareProtectedCollateralToken1;

methods {
    // ---- `Silo` -------------------------------------------------------------
    // Getters
    function Silo0.getTotalAssetsStorage(uint256) external returns(uint256) envfree;
    function Silo1.getTotalAssetsStorage(uint256) external returns(uint256) envfree;

    function Silo0.config() external returns (address) envfree;
    function Silo1.config() external returns (address) envfree;

    // Harness
    function Silo0.getSiloDataInterestRateTimestamp() external returns(uint64) envfree;
    function Silo1.getSiloDataInterestRateTimestamp() external returns(uint64) envfree;

    function Silo0.getSiloDataDaoAndDeployerRevenue() external returns(uint192) envfree;
    function Silo1.getSiloDataDaoAndDeployerRevenue() external returns(uint192) envfree;

    // Dispatcher
    function _.getTotalAssetsStorage(uint256) external => DISPATCHER(true);
    function _.accrueInterest() external => DISPATCHER(true);
    function _.getCollateralAndProtectedTotalsStorage() external  => DISPATCHER(true);
    function _.isSolvent(address) external => DISPATCHER(true);

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
    function _.getDebtShareTokenAndAsset(address) external  => DISPATCHER(true);

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
    function _.beforeQuote(address) external => NONDET DELETE;

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
    //function _._afterTokenTransfer(address,address,uint256) internal => CONSTANT;
    
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
    function Silo0.balanceOf(address) external returns (uint256) envfree;
    function ShareDebtToken0.balanceOf(address) external returns (uint256) envfree;
    function ShareProtectedCollateralToken0.balanceOf(address) external returns (uint256) envfree;
    
    function Token0.totalSupply() external returns (uint256) envfree;
    function Silo0.totalSupply() external returns (uint256) envfree;
    function ShareDebtToken0.totalSupply() external returns (uint256) envfree;
    function ShareProtectedCollateralToken0.totalSupply() external returns (uint256) envfree;
    
    function Silo0.silo() external returns (address) envfree;
    function ShareDebtToken0.silo() external returns (address) envfree;
    function ShareProtectedCollateralToken0.silo() external returns (address) envfree;

    function Silo0.siloConfig() external returns (address) envfree;
    function ShareDebtToken0.siloConfig() external returns (address) envfree;
    function ShareProtectedCollateralToken0.siloConfig() external returns (address) envfree;
    
    function Token1.balanceOf(address) external returns (uint256) envfree;
    function Silo1.balanceOf(address) external returns (uint256) envfree;
    function ShareDebtToken1.balanceOf(address) external returns (uint256) envfree;
    function ShareProtectedCollateralToken1.balanceOf(address) external returns (uint256) envfree;
    
    function Token1.totalSupply() external returns (uint256) envfree;
    function Silo1.totalSupply() external returns (uint256) envfree;
    function ShareDebtToken1.totalSupply() external returns (uint256) envfree;
    function ShareProtectedCollateralToken1.totalSupply() external returns (uint256) envfree;

    function Silo1.silo() external returns (address) envfree;
    function ShareDebtToken1.silo() external returns (address) envfree;
    function ShareProtectedCollateralToken1.silo() external returns (address) envfree;

    function Silo1.siloConfig() external returns (address) envfree;
    function ShareDebtToken1.siloConfig() external returns (address) envfree;
    function ShareProtectedCollateralToken1.siloConfig() external returns (address) envfree;

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



    function _.onFlashLoan(address _initiator, address _token, uint256 _amount, uint256 _fee, bytes _data)
        external => NONDET; 

    function _.synchronizeHooks(uint24 _hooksBefore, uint24 _hooksAfter) external => DISPATCHER(true);
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
    require require_uint64(e.block.timestamp) >= silo0.getSiloDataInterestRateTimestamp();
    require require_uint64(e.block.timestamp) >= silo1.getSiloDataInterestRateTimestamp();
}


/// @title Set an address that is different from all contracts in the scene
function siloSetupAddress(address sender) {
    require sender != shareDebtToken0;
    require sender != shareProtectedCollateralToken0;
    require sender != shareProtectedCollateralToken1;
    require sender != shareDebtToken1;
    require sender != siloConfig;
    require sender != currentContract;  // `Silo0`
    require sender != silo1;
    require sender != token0;
    require sender != token1;
    //todo - check if this is safe 
    //IShareToken.ShareTokenStorage data = ShareTokenLib.getShareTokenStorage();
    //require sender != data.hookSetup.hookReceiver ...
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

// ---- Reentrancy Rules ----

///

definition NOT_ENTERED() returns uint256 = 1; 
definition ENTERED() returns uint256 = 2; 

ghost bool reentrantStatusMovedToTrue;
ghost bool reentrantStatusLoaded; 

//update movedToTrue, stays true or become true when _crossReentrantStatus is entered 
hook Sstore siloConfig._crossReentrantStatus uint256 new_value (uint old_value) {
    reentrantStatusMovedToTrue =  reentrantStatusMovedToTrue || (new_value == ENTERED())  && old_value == NOT_ENTERED(); 
}

hook Sload uint256 value  siloConfig._crossReentrantStatus {
    reentrantStatusLoaded =  true;
}

/// @title Accruing interest in Silo0 (in the same block) should not change any borrower's LtV.
invariant RA_reentrancyGuardStaysUnlocked()
    siloConfig._crossReentrantStatus == NOT_ENTERED()
    { preserved with (env e) 
        { 
            setupTokensSharesConfig();
            setupSiloEnvTimestamp(e);
            siloSetupAddress(e.msg.sender);
        } 
}


rule RA_whoMustLoadCrossNonReentrant(method f) filtered {f-> !f.isView}{
    env e;
    require !reentrantStatusLoaded; 
    requireInvariant RA_reentrancyGuardStaysUnlocked();
    setupTokensSharesConfig();
    setupSiloEnvTimestamp(e);
    siloSetupAddress(e.msg.sender);
    calldataarg args;
    f(e,args);
    assert reentrantStatusLoaded; 
} 

rule RA_reentrancyGuardStatus_change(method f) filtered {f-> !f.isView}{
    env e;
    uint256 valueBefore = siloConfig._crossReentrantStatus;
    require !reentrantStatusMovedToTrue; 
    setupTokensSharesConfig();
    setupSiloEnvTimestamp(e);
    siloSetupAddress(e.msg.sender);
    calldataarg args;
    f(e,args);
    assert reentrantStatusMovedToTrue; 
    assert valueBefore == NOT_ENTERED();
}