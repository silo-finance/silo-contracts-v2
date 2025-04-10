methods
{

    function _.deposit(uint256 _assets, address _receiver, ISilo.CollateralType _collateralType) external 
        => simpleDepositCVL(_assets, _receiver, _collateralType) expect (uint256);
    
    function _.withdraw(uint256 _assets, address _receiver, address _owner, ISilo.CollateralType _collateralType) external 
        => simpleWithdrawCVL(_assets, _receiver, _owner, _collateralType) expect (uint256);
    
    function _.borrow(uint256 _assets, address _receiver, address _borrower) external 
        => simpleBorrowCVL(_assets, _receiver, _borrower) expect (uint256);
    
    function _.repay(uint256 _assets, address _borrower) external 
        => simpleRepayCVL(_assets, _borrower) expect (uint256);
    
    // we deliberatelly ignore the "token". See comments on safeTransferFromCVL.
    function _.safeTransferFrom(address token, address from, address to, uint256 amount) internal 
        => safeTransferFromCVL(from, to, amount) expect void;
}

// keeps track of all calls to Silo methods and stores the arguments
// e.g. when deposit(x) is called it stores here that totalSilo0Col increases by x, etc.
// the changes are NOT EXACT. We ommit many factors like interest, rounding, share <-> asset conversion, etc.
// these are not supposed to mirror the storage of Silo but rather log which methods were called on Silo
ghost uint256 totalSilo0Col;
ghost uint256 totalSilo0ProtCol;
ghost uint256 totalSilo0Debt;
ghost address silo0Address;
ghost address originalCaller;

ghost mapping(address => uint256) depositedCollateral;
ghost mapping(address => uint256) depositedProtCollateral;
ghost mapping(address => uint256) debtSharesHolding;
ghost mapping(address => uint256) receivedShares;
ghost mapping(address => uint256) receivedProtShares;

function simpleDepositCVL(uint256 _assets, address _receiver, ISilo.CollateralType _collateralType) returns uint256
{
    if (_collateralType == ISilo.CollateralType.Protected)
    { 
        totalSilo0ProtCol = require_uint256(totalSilo0ProtCol + _assets);
        depositedProtCollateral[originalCaller] = require_uint256(depositedProtCollateral[originalCaller] + _assets);

        uint256 sharesProtCol;
        return sharesProtCol;
    }
    else
    { 
        totalSilo0Col = require_uint256(totalSilo0Col + _assets);
        depositedCollateral[originalCaller] = require_uint256(depositedCollateral[originalCaller] + _assets);
        uint256 sharesProtCol;
        return sharesProtCol;
    }
}

function simpleWithdrawCVL(uint256 _assets, address _receiver, address _owner, ISilo.CollateralType _collateralType) returns uint256
{
    if (_collateralType == ISilo.CollateralType.Protected)
    { 
        totalSilo0ProtCol = require_uint256(totalSilo0ProtCol - _assets);
        depositedProtCollateral[_owner] = require_uint256(depositedProtCollateral[_owner] - _assets);
        uint256 sharesProtCol;
        return sharesProtCol;
    }
    else
    { 
        totalSilo0Col = require_uint256(totalSilo0Col - _assets);
        depositedCollateral[_owner] = require_uint256(depositedCollateral[_owner] - _assets);
        uint256 sharesCol;
        return sharesCol;
    }
}

function simpleBorrowCVL(uint256 _assets, address _receiver, address _borrower) returns uint256
{ 
    totalSilo0Debt = require_uint256(totalSilo0Debt + _assets);
    debtSharesHolding[_borrower] = require_uint256(debtSharesHolding[_borrower] + _assets);
    uint256 shares;
    return shares;
}

function simpleRepayCVL(uint256 _assets, address borrower) returns uint256
{
    totalSilo0Debt = require_uint256(totalSilo0Debt - _assets);
    debtSharesHolding[borrower] = require_uint256(debtSharesHolding[borrower] - _assets);
    uint256 shares;
    return shares;
}

// Any of the tokens could be transfered so here we just pretend that
// ALL of them were transfered. This is a safe approach, an over-approximation
// that's good enought for our purposes.
function safeTransferFromCVL(address from, address to, uint256 amount)
{
    depositedCollateral[from] = require_uint256(depositedCollateral[from] - amount);
    depositedProtCollateral[from] = require_uint256(depositedProtCollateral[from] - amount);
    debtSharesHolding[from] = require_uint256(debtSharesHolding[from] - amount);
    receivedShares[from] = require_uint256(receivedShares[from] - amount);
    receivedProtShares[from] = require_uint256(receivedProtShares[from] - amount);

    depositedCollateral[to] = require_uint256(depositedCollateral[to] + amount);
    depositedProtCollateral[to] = require_uint256(depositedProtCollateral[to] + amount);
    debtSharesHolding[to] = require_uint256(debtSharesHolding[to] + amount);
    receivedShares[to] = require_uint256(receivedShares[to] + amount);
    receivedProtShares[to] = require_uint256(receivedProtShares[to] + amount);

}
 

