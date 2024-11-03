/* Multiple `ERC20` implementations in CVL

   Replaces the implementation in `openzeppelin5-upgradeable/token/ERC20/ERC20Upgradeable.sol`.
   This helps reduce the complexity of rules, thereby reducing running times and solving
   timeouts.

   Downsides to be aware of:
   - The code here cannot model reverts!
   - Soundness of the code yet to be checked.
*/

methods {
    function _.totalSupply() internal => totalSupplyByToken[calledContract] expect uint256;
    function _.balanceOf(
        address a
    ) internal => balanceByToken[calledContract][a] expect uint256;
    function _.allowance(
        address a,
        address b
    ) internal => allowanceByToken[calledContract][a][b] expect uint256;
    function _.approve(
        address a,
        uint256 x
    ) internal with (env e) => approveCVL(calledContract, e.msg.sender, a, x) expect bool;
    function _.transfer(
        address a, uint256 x
    ) internal with (env e) => transferCVL(calledContract, e.msg.sender, a, x) expect bool;
    function _.transferFrom(
        address a,
        address b,
        uint256 x
    ) internal with (env e) => transferFromCVL(calledContract, e.msg.sender, a, b, x) expect bool;

    function _._mint(
        address account,
        uint256 value
    ) internal => _mintCVL(calledContract, account, value) expect void;
    function _._burn(
        address account,
        uint256 value
    ) internal => _burnCVL(calledContract, account, value) expect void;
    
    // NOTE: called by `forwardTransferFromNoChecks`, hence must be summarized
    function _._transfer(
        address from,
        address to,
        uint256 value
    ) internal => _transferCVL(calledContract, from, to, value) expect void;
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


/// @title Implementation of `ERC20.transfer` in CVL
function transferCVL(address token, address from, address to, uint256 amount) returns bool {
    // should be randomly reverting
    bool nondetSuccess;
    if (!nondetSuccess) return false;

    if(balanceByToken[token][from] < amount) return false;
    _transferCVL(token, from, to, amount);
    return true;
}


/// @title Implementation of the internal function `ERC20._transfer` in CVL
function _transferCVL(address token, address from, address to, uint256 amount) {
    balanceByToken[token][from] = require_uint256(balanceByToken[token][from] - amount);
    // We neglect overflows.
    balanceByToken[token][to] = require_uint256(balanceByToken[token][to] + amount);
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
