methods {

    function maxDeployerFee() external returns uint256 envfree;
    function maxFlashloanFee() external returns uint256 envfree;
    function maxLiquidationFee() external returns uint256 envfree;
    
    function MAX_FEE() external returns uint256 envfree;

    function _.cloneDeterministic(address master, bytes32 salt) internal =>
        cloneDeterministicCVL(master, salt) expect address;

    function _.initialize(address _silo, address _hookReceiver, uint24 _tokenType) external =>
        initializeCVL(_silo, _hookReceiver, _tokenType) expect void;

    function _.quoteToken() external => NONDET; // PER_CALLEE_CONSTANT ?

    // from https://github.com/Certora/ProjectSetup/blob/main/certora/specs/ERC721/erc721.spec
    // likely unsound, but assumes no callback
    function _.onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes data
    ) external => NONDET; /* expects bytes4 */
}

// "clone address" -> "has already been deployed"
ghost mapping(address => bool) deployed;

ghost mapping(address => mapping(bytes32 => address)) clonedet;
ghost mapping(address => address) clonedet_rev1;
ghost mapping(address => bytes32) clonedet_rev2;


function cloneDeterministicCVL(address master, bytes32 salt) returns address {
    address res = clonedet[master][salt]; // keccak256(master) +  keccak256(salt);

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
ghost mapping(address => mapping(address => mapping(uint24 => bool))) already_initialized;

function initializeCVL(address _silo, address _hookReceiver, uint24 _tokenType) {
    assert(false, "this isn't called right now, is it?  (just checking, not a requirement)");

    share_token_silo[_hookReceiver] = _silo;

    // make sure this is never called on the same inputs twice (TODO: double check -- do all the inputs count, or only a subset?)
    assert(!already_initialized[_silo][_hookReceiver][_tokenType]); 
    already_initialized[_silo][_hookReceiver][_tokenType] = true;
}

//use builtin rule sanity filtered { f -> f.contract == currentContract }

invariant deployerFeeInRange()
    maxDeployerFee() <= MAX_FEE();

invariant flashLoanFeeInRange()
    maxFlashloanFee() <= MAX_FEE();

invariant liquidationFeeInRange()
    maxLiquidationFee() <= MAX_FEE();