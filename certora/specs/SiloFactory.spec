using SiloConfig as theSiloConfig;

methods {

    function maxDeployerFee() external returns uint256 envfree;
    function maxFlashloanFee() external returns uint256 envfree;
    function maxLiquidationFee() external returns uint256 envfree;
    function daoFeeRange() external returns ISiloFactory.Range envfree;
    
    
    function MAX_FEE() external returns uint256 envfree;

    function _.cloneDeterministic(address master, bytes32 salt) internal =>
        cloneDeterministicCVL(master, salt) expect address;

    // a function of ISharedTokenInitializable
    function _.initialize(address _silo, address _hookReceiver, uint24 _tokenType) external =>
        initializeCVL_3(calledContract, _silo, _hookReceiver, _tokenType) expect void;

    // a function of ISilo
    function _.initialize(address siloConfig) external =>
        initializeCVL_1(calledContract, siloConfig) expect void;

    function _.quoteToken() external => NONDET; // PER_CALLEE_CONSTANT ?

    // from https://github.com/Certora/ProjectSetup/blob/main/certora/specs/ERC721/erc721.spec
    // likely unsound, but assumes no callback
    function _.onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes data
    ) external => NONDET; /* expects bytes4 */

    function _.updateHooks() external => NONDET;
    function _.config() external => configCVL(calledContract) expect address;
    function _.SILO_ID() external => PER_CALLEE_CONSTANT;
    
    function _.tokenURI() external returns string envfree => NONDET;
    
    function _initializeShareTokens(
        ISiloConfig.ConfigData memory configData0,
        ISiloConfig.ConfigData memory configData1) internal
        => initShareTokensCVL(configData0, configData1);

}

//// summary: config ////

ghost configDet(address) returns address; 

function configCVL(address calledC) returns address {
    if (already_initialized_1[calledC]) {
        return configDet(calledC);
    } else {
        return 0;
    }
}

//// summary: cloneDeterministic ////

// "clone address" -> "has already been deployed"
ghost mapping(address => bool) deployed;

ghost mapping(address => mapping(bytes32 => address)) clonedet;
ghost mapping(address => address) clonedet_rev1;
ghost mapping(address => bytes32) clonedet_rev2;


function cloneDeterministicCVL(address master, bytes32 salt) returns address {
    address res = clonedet[master][salt]; 

    // injectivity (could also use quantifiers + ghost axioms)
    require(clonedet_rev1[res] == master);
    require(clonedet_rev2[res] == salt);

    // can't deploy the same twice
    require(!deployed[res]); 
    deployed[res] = true;

    return res;
}


//// summary: ISharedTokenInitializable.initialize(<three args>) ////

// "share token" -> "silo"
ghost mapping(address => address) share_token_silo;

ghost mapping(address => bool) already_initialized_3;

function initializeCVL_3(address calledC, address _silo, address _hookReceiver, uint24 _tokenType) {
    share_token_silo[_hookReceiver] = _silo;

    // make sure this is never called on the same inputs twice
    assert(!already_initialized_3[calledC]); 
    already_initialized_3[calledC] = true;
}

// call this at the beginning of rules to avoid the assertion in `initializeCVL_3` from 
// failing spuriously
function init_already_initialized_3() {
    require(forall address a. !already_initialized_3[a]);
}

//// summary: ISilo.initialize(<one arg>) ////

ghost mapping(address => bool) already_initialized_1;

function initializeCVL_1(address calledC, address siloConfig) {
    // make sure this is never called on the same inputs twice 
    assert(!already_initialized_1[calledC]); 
    already_initialized_1[calledC] = true;
}

// call this at the beginning of rules to avoid the assertion in `initializeCVL_1` from 
// failing spuriously
function init_already_initialized_1() {
    require(forall address a. !already_initialized_1[a]);
}

//// rules ////
//use builtin rule sanity filtered { f -> f.contract == currentContract }

invariant deployerFeeInRange()
    maxDeployerFee() <= MAX_FEE();

invariant flashLoanFeeInRange()
    maxFlashloanFee() <= MAX_FEE();

invariant liquidationFeeInRange()
    maxLiquidationFee() <= MAX_FEE();

invariant DAOFeeInRange()
    daoFeeRange().min <= daoFeeRange().max && 
    daoFeeRange().max <= MAX_FEE();

rule consitencyOfCreatedSilos(env e)
{
    ISiloConfig.InitData initData;
    address config;
    require config == theSiloConfig;
    address siloImpl; address shareProtectedCollateralTokenImpl; address shareDebtTokenImpl;
    createSilo(initData, config, siloImpl, shareProtectedCollateralTokenImpl, shareDebtTokenImpl);
    satisfy true;
}