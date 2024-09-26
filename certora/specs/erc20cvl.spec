/* Multiple `ERC20` implementations in CVL

   Replaces the implementation in `openzeppelin5-upgradeable/token/ERC20/ERC20Upgradeable.sol`.
   This helps reduce the complexity of rules, thereby reducing running times and solving
   timeouts.

   Downsides to be aware of:
   - The code here cannot model reverts!
   - Soundness of the code yet to be checked.
   - Only external functions were summarized - this relies on a lack of any internal
     calls to public functions. If the code changes, this assumption should be rechecked.
    
    Note. Since the `ShareToken` contracts inherit the `ERC20` we should summarize the
    internal functions. However, since there are also external calls such as
    `IShareToken(_shareToken).totalSupply()`, we summarize only the external calls.
*/

using ShareDebtToken0 as shareDebtToken0;
using ShareProtectedCollateralToken0 as shareProtectedCollateralToken0;

using ShareDebtToken1 as shareDebtToken1;
using ShareProtectedCollateralToken1 as shareProtectedCollateralToken1;

methods {
    // Standard `ERC20`
    function _.decimals() external => PER_CALLEE_CONSTANT;  // Not called internally

    // The functions `name` and `symbol` are deleted since they cause memory partitioning
    // problems.
    function _.name() external => PER_CALLEE_CONSTANT DELETE;
    function _.symbol() external => PER_CALLEE_CONSTANT DELETE;

    function _.totalSupply() external => totalSupplyByToken[calledContract] expect uint256 DELETE;
    function _.balanceOf(
        address a
    ) external => balanceByToken[calledContract][a] expect uint256 DELETE;
    function _.allowance(
        address a,
        address b
    ) external => allowanceByToken[calledContract][a][b] expect uint256 DELETE;
    function _.approve(
        address a,
        uint256 x
    ) external with (env e) => approveCVL(calledContract, e.msg.sender, a, x) expect bool DELETE;
    function _.transfer(
        address a, uint256 x
    ) external with (env e) => transferCVL(calledContract, e.msg.sender, a, x) expect bool DELETE;
    function _.transferFrom(
        address a,
        address b,
        uint256 x
    ) external with (env e) => transferFromCVL(calledContract, e.msg.sender, a, b, x) expect bool DELETE;

    // `IShareToken` (these functions are only external, not public)
    function _.mint(
        address _owner,
        address _spender,
        uint256 _amount
    ) external with (env e) => shareTokenMintCVL(
        calledContract,
        _owner,
        _spender,
        _amount
    ) expect void DELETE;
    function _.burn(
        address _owner,
        address _spender,
        uint256 _amount
    ) external with (env e) => shareTokenBurnCVL(
        calledContract,
        _owner,
        _spender,
        _amount
    ) expect void DELETE;

    function _.balanceOfAndTotalSupply(
        address _account
    ) external => balanceOfAndTotalSupplyCVL(calledContract, _account) expect (uint256, uint256);

    function _.forwardTransferFromNoChecks(
        address _from,
        address _to,
        uint256 _amount
    ) external with (env e) => transferFromNoChecksCVL(
        calledContract,
        e.msg.sender,
        _from,
        _to,
        _amount
    ) expect void DELETE;
}

// ---- Storage ----------------------------------------------------------------

// Simple implementation of multiple `ERC20` storage in CVL using ghost variables.
// NOTE: ordinary (non-persistent) ghost variables will be havoc-d similar to storage
// variables.

// token => total supply
ghost mapping(address => uint256) totalSupplyByToken;

/// token => account => balance
ghost mapping(address => mapping(address => uint256)) balanceByToken;

/// token => owner => spender => allowance
ghost mapping(address => mapping(address => mapping(address => uint256))) allowanceByToken;

// ---- Implementations --------------------------------------------------------

/// @title Implementation of `ERC20.approve` in CVL
function approveCVL(
    address token,
    address approver,
    address spender,
    uint256 amount
) returns bool {
    // NOTE: Randomly fails
    bool nondetSuccess;
    if (!nondetSuccess) return false;

    allowanceByToken[token][approver][spender] = amount;
    return true;
}


/// @title Implementation of `ERC20.transferFrom` in CVL
function transferFromCVL(
    address token,
    address spender,
    address from,
    address to,
    uint256 amount
) returns bool {
    // NOTE: Randomly fails
    bool nondetSuccess;
    if (!nondetSuccess) return false;

    if (allowanceByToken[token][from][spender] < amount) return false;
    allowanceByToken[token][from][spender] = require_uint256(
        allowanceByToken[token][from][spender] - amount
    );
    return transferCVL(token, from, to, amount);
}


/// @title Implementation of `forwardTransferFromNoChecks` in CVL
/// TODO: Does not revert!
function transferFromNoChecksCVL(
    address token,
    address msgSender,
    address from,
    address to,
    uint256 amount
) {
    require msgSender == currentContract;
    transferCVL(token, from, to, amount);
}


/// @title Implementation of `ERC20.transfer` in CVL
function transferCVL(address token, address from, address to, uint256 amount) returns bool {
    // should be randomly reverting xxx
    bool nondetSuccess;
    if (!nondetSuccess) return false;

    if(balanceByToken[token][from] < amount) return false;
    balanceByToken[token][from] = require_uint256(balanceByToken[token][from] - amount);
    // We neglect overflows.
    balanceByToken[token][to] = require_uint256(balanceByToken[token][to] + amount);
    return true;
}


/// @title Implementation of `ShareToken.mint` in CVL
function shareTokenMintCVL(
    address token, 
    address _owner,
    address _spender,
    uint256 _amount
) {
    if (token == shareDebtToken0 || token == shareDebtToken1) {
        _spendAllowanceCVL(token, _owner, _spender, _amount);
    }
    _mintCVL(token, _owner, _amount);
}


/// @title Implementation of `ShareToken.burn` in CVL
function shareTokenBurnCVL(
    address token, 
    address _owner,
    address _spender,
    uint256 _amount
) {
    if (
        token == silo0 || token == silo1 ||
        token == shareProtectedCollateralToken0 || token == shareProtectedCollateralToken1
       ) {
        _spendAllowanceCVL(token, _owner, _spender, _amount);
    }
    _burnCVL(token, _owner, _amount);
}


/// @title Implementation of `ERC20Upgradeable._spendAllowance` in CVL
function _spendAllowanceCVL(
    address token, 
    address owner,
    address spender,
    uint256 value
) {
    if (allowanceByToken[token][owner][spender] != max_uint256 && owner != spender) {

        // `ERC20Upgradeable._spendAllowance` reverts if current allowance too low
        require allowanceByToken[token][owner][spender] >= value;

        allowanceByToken[token][owner][spender] = value;
    }
}


/// @title Implementation of `ERC20Upgradeable._mint` in CVL
function _mintCVL(address token, address to, uint256 amount) {

    // According to `openzeppelin5-upgradeable/token/ERC20/ERC20Upgradeable.sol` minting
    // to address zero reverts.
    require to != 0;

    balanceByToken[token][to] = require_uint256(balanceByToken[token][to] + amount);
    totalSupplyByToken[token] = require_uint256(totalSupplyByToken[token] + amount);
}


/// @title Implementation of `ERC20Upgradeable._burn` in CVL
function _burnCVL(address token, address from, uint256 amount){

    // According to `openzeppelin5-upgradeable/token/ERC20/ERC20Upgradeable.sol` burning
    // from address zero reverts.
    require from != 0;

    balanceByToken[token][from] = require_uint256(balanceByToken[token][from] - amount);
    totalSupplyByToken[token] = require_uint256(totalSupplyByToken[token] - amount);
}


/// @title Implementation of `ShareToken.balanceOfAndTotalSupply` in CVL
function balanceOfAndTotalSupplyCVL(
    address token,
    address _account
) returns (uint256, uint256) {
    return (balanceByToken[token][_account], totalSupplyByToken[token]);
}

// ---- Helper functions -------------------------------------------------------

/// @title Requires that total supply is more than balances
function totalSupplyMoreThanBalanceERC20(address token, address user) {
    if (user != currentContract) {
        require totalSupplyByToken[token] >= require_uint256(
            balanceByToken[token][user] + balanceByToken[token][currentContract]
        );
    } else {
        require totalSupplyByToken[token] >= balanceByToken[token][user];
    }
}       
