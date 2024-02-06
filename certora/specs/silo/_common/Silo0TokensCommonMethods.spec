methods {
    function _.transferFrom(address from, address to, uint256 amount) external with (env e)
        => transferFromSumm(e, calledContract, from, to, amount) expect bool UNRESOLVED;
    function _.transfer(address to, uint256 amount) external with (env e)
        => transferSumm(e, calledContract, to, amount) expect bool UNRESOLVED;
    function _.totalSupply() external => totalSupplySumm(calledContract) expect uint256 UNRESOLVED;
    function _.balanceOf(address account) external => balanceOfSumm(calledContract, account) expect uint256 UNRESOLVED;
}

function totalSupplySumm(address callee) returns uint256 {
    uint256 totalSupply;

    if(callee == shareCollateralToken0) {
        require totalSupply == shareCollateralToken0.totalSupply();
    } else if(callee == shareProtectedCollateralToken0) {
        require totalSupply == shareProtectedCollateralToken0.totalSupply();
    } else if (callee == shareDebtToken0) {
        require totalSupply == shareDebtToken0.totalSupply();
    } else if (callee == token0) {
        require totalSupply == token0.totalSupply();
    } else {
        assert false;
    }

    return totalSupply;
}

function balanceOfSumm(address callee, address account) returns uint256 {
    uint256 balanceOfAccount;

    if(callee == shareDebtToken0) {
        require balanceOfAccount == shareDebtToken0.balanceOf(account);
    } else if (callee == shareCollateralToken0) {
        require balanceOfAccount == shareCollateralToken0.balanceOf(account);
    } else if (callee == shareProtectedCollateralToken0) {
        require balanceOfAccount == shareProtectedCollateralToken0.balanceOf(account);
    } else if (callee == token0) {
        require balanceOfAccount == token0.balanceOf(account);
    } else {
       assert false;
    }

    return balanceOfAccount;
}

function transferFromSumm(env e, address callee, address from, address to, uint256 amount) returns bool {
    bool success;

    if(callee == shareDebtToken0) {
        require success == shareDebtToken0.transferFrom(e, from, to, amount);
    } else if(callee == shareCollateralToken0) {
        require success == shareCollateralToken0.transferFrom(e, from, to, amount);
    } else if(callee == shareProtectedCollateralToken0) {
        require success == shareProtectedCollateralToken0.transferFrom(e, from, to, amount);
    } else if(callee == token0) {
        require success == token0.transferFrom(e, from, to, amount);
    } else {
        assert false;
    }

    return success;
}

function transferSumm(env e, address callee, address to, uint256 amount) returns bool {
    bool success;

    if(callee == shareDebtToken0) {
        require success == shareDebtToken0.transfer(e, to, amount);
    } else if(callee == shareCollateralToken0) {
        require success == shareCollateralToken0.transfer(e, to, amount);
    } else if(callee == shareProtectedCollateralToken0) {
        require success == shareProtectedCollateralToken0.transfer(e, to, amount);
    } else if(callee == token0) {
        require success == token0.transfer(e, to, amount);
    } else {
        assert false;
    }

    return success;
}
