using SiloConfig as theSiloConfig;

methods {

    function maxDeployerFee() external returns uint256 envfree;
    function maxFlashloanFee() external returns uint256 envfree;
    function maxLiquidationFee() external returns uint256 envfree;
    function daoFeeRange() external returns ISiloFactory.Range envfree;
    function getOwner(uint256) external returns address;
    
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
    
    function _.tokenURI() external => NONDET;
    
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
    require master == siloImplAddress => (res == silo0Address || res == silo1Address);

    // injectivity (could also use quantifiers + ghost axioms)
    require(clonedet_rev1[res] == master);
    require(clonedet_rev2[res] == salt);

    // can't deploy the same twice
    require(!deployed[res]); 
    deployed[res] = true;

    return res;
}

// "share token" -> "silo"
ghost mapping(address => address) share_token_silo;

ghost mapping(address => bool) already_initialized_3
{
    init_state axiom forall address a. already_initialized_3[a] == false;
}

function initializeCVL_3(address calledC, address _silo, address _hookReceiver, uint24 _tokenType) {
    share_token_silo[calledC] = _silo;

    // make sure this is never called on the same inputs twice
    assert(!already_initialized_3[calledC]); 
    already_initialized_3[calledC] = true;
    mirrorStorage_3(calledC, _silo, _hookReceiver, _tokenType);
}

// call this at the beginning of rules to avoid the assertion in `initializeCVL_3` from 
// failing spuriously
function init_already_initialized_3() {
    require(forall address a. !already_initialized_3[a]);
}

//// summary: ISilo.initialize(<one arg>) ////

ghost mapping(address => bool) already_initialized_1;

function initializeCVL_1(address calledSilo, address siloConfig) {
    // make sure this is never called on the same inputs twice 
    assert(!already_initialized_1[calledSilo]); 
    already_initialized_1[calledSilo] = true;
    mirrorStorage_1(calledSilo, siloConfig);
}

function initializeGhosts()
{
    require forall address a. !already_initialized_3[a];
    require forall address a. !already_initialized_1[a];
    require forall address a. !deployed[a];
    require silo0Address != silo1Address;
    require theSiloConfig._SILO0 == silo0Address;
    require theSiloConfig._SILO1 == silo1Address;

    COLLATERAL_TOKEN = 2^11;
    PROTECTED_TOKEN = 2^12;
    DEBT_TOKEN = 2^13;
}

ghost uint24 COLLATERAL_TOKEN;
ghost uint24 PROTECTED_TOKEN;
ghost uint24 DEBT_TOKEN;

ghost address silo0Address; 
ghost address silo1Address;
ghost address siloImplAddress; //argument to createSilo;
ghost mapping (address => address) siloAddressByContractStorage;
ghost mapping (address => address) configAddressByContractStorage;
ghost mapping (address => address) hookReceiverByContractStorage;
ghost mapping (address => uint24) tokenTypeByContractStorage;
ghost mapping (address => bool) transferWithChecksByContractStorage;

// this is executed instead of Silo.initialize
// it stores the contract data in ghost variables so that we can later check that
// the contract is initialized properly without having to include Silo in the scene.
function mirrorStorage_1(address calledSilo, address siloConfig)
{
    assert siloConfig == theSiloConfig;
    siloAddressByContractStorage[calledSilo] = calledSilo;
    configAddressByContractStorage[calledSilo] = siloConfig;
    //hookReceiverByContractStorage[calledSilo] = _hookReceiver;
    tokenTypeByContractStorage[calledSilo] = COLLATERAL_TOKEN;
    transferWithChecksByContractStorage[calledSilo] = true;
}

// this is executed instead of ShareToken.initialize
// it stores the contract data in ghost variables so that we can later check that
// the contract is initialized properly without having to include Silo in the scene.
function mirrorStorage_3(address calledC, address _silo, address _hookReceiver, uint24 _tokenType)
{
    siloAddressByContractStorage[calledC] = _silo;
    //configAddressByContractStorage[calledC] = siloConfig;
    hookReceiverByContractStorage[calledC] = _hookReceiver;
    tokenTypeByContractStorage[calledC] = _tokenType;
    transferWithChecksByContractStorage[calledC] = true;
}

//// rules ////

function requireAllDifferent(address a1, address a2, address a3, address a4)
{
    require a1 != a2 &&
        a1 != a3 &&
        a1 != a4 &&
        a2 != a3 &&
        a2 != a4 &&
        a3 != a4;
}

rule integrityOfCreatedSilos(env e)
{
    initializeGhosts();
    ISiloConfig.InitData initData;
    address shareProtectedCollateralTokenImpl; address shareDebtTokenImpl;
    requireAllDifferent(shareProtectedCollateralTokenImpl, 
        shareDebtTokenImpl, theSiloConfig, siloImplAddress);

    createSilo(e, initData, theSiloConfig, siloImplAddress, shareProtectedCollateralTokenImpl, shareDebtTokenImpl);
    
    ISiloConfig.ConfigData configDataSilo0 = theSiloConfig.getConfig(e, silo0Address);
    ISiloConfig.ConfigData configDataSilo1 = theSiloConfig.getConfig(e, silo1Address);
    
    // checks silo address and config address are correctly set
    assert configDataSilo0.silo == siloAddressByContractStorage[silo0Address];
    assert configAddressByContractStorage[silo0Address] == theSiloConfig;

    assert configDataSilo1.silo == siloAddressByContractStorage[silo1Address];
    assert configAddressByContractStorage[silo1Address] == theSiloConfig;

    // checks that tokenType is correctly set
    address clonedFrom; bytes32 salt;
    
    // this assures the correctness of backlink
    // otherwise there could be x1, x2 s.t.
    // clonedet[x1][salt] = clonedet[x2][salt] which violates this property
    require clonedFrom == clonedet_rev1[clonedet[clonedFrom][salt]];
    assert (clonedFrom == shareProtectedCollateralTokenImpl 
            && deployed[clonedet[clonedFrom][salt]]) =>
        tokenTypeByContractStorage[clonedet[clonedFrom][salt]] == PROTECTED_TOKEN;
        
    assert (clonedFrom == siloImplAddress 
            && deployed[clonedet[clonedFrom][salt]]) =>
        tokenTypeByContractStorage[clonedet[clonedFrom][salt]] == COLLATERAL_TOKEN;
    
    assert (clonedFrom == shareDebtTokenImpl 
            && deployed[clonedet[clonedFrom][salt]]) =>
        tokenTypeByContractStorage[clonedet[clonedFrom][salt]] == DEBT_TOKEN;

    // to make sure it's not vacuous
    satisfy true;
}