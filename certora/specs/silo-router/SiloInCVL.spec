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
    
}

// todo add comments
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

 

