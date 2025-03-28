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
    function _.getShareTokens(address) external => DISPATCHER(true);  
    
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
//// summary: ISilo.initialize(<one arg>) ////

ghost mapping(address => bool) already_initialized_1;

function initializeCVL_1(address calledSilo, address siloConfig) {
    // make sure this is never called on the same inputs twice 
    assert(!already_initialized_1[calledSilo]); 
    already_initialized_1[calledSilo] = true;
}

ghost mapping(address => bool) already_initialized_3
{
    init_state axiom forall address a. already_initialized_3[a] == false;
}

function initializeCVL_3(address calledC, address _silo, address _hookReceiver, uint24 _tokenType) {
    // make sure this is never called on the same inputs twice
    assert(!already_initialized_3[calledC]); 
    already_initialized_3[calledC] = true;
}

// call this at the beginning of rules to avoid the assertion in `initializeCVL_x` from 
// failing spuriously
function init_already_initialized() {
    require(forall address a. !already_initialized_1[a]);
    require(forall address a. !already_initialized_3[a]);
}


//// rules ////

invariant deployerFeeInRange()
    maxDeployerFee() <= MAX_FEE()
    {
        preserved { init_already_initialized(); }
    }


invariant flashLoanFeeInRange()
    maxFlashloanFee() <= MAX_FEE()
    {
        preserved { init_already_initialized(); }
    }

invariant liquidationFeeInRange()
    maxLiquidationFee() <= MAX_FEE()
    {
        preserved { init_already_initialized(); }
    }

invariant DAOFeeInRange()
    daoFeeRange().min <= daoFeeRange().max && 
    daoFeeRange().max <= MAX_FEE()
    {
        preserved { init_already_initialized(); }
    }

rule onlySiloOwnerCanBurn(env e)
{
    uint256 siloIdToBurn;
    address ownerOfSilo = getOwner(e, siloIdToBurn);
    burn@withrevert(e, siloIdToBurn);
    bool reverted = lastReverted;
    assert e.msg.sender != ownerOfSilo => reverted;
}