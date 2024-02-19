using ShareCollateralToken1 as shareCollateralToken1;
using ShareProtectedCollateralToken1 as shareProtectedCollateralToken1;
using ShareDebtToken1 as shareDebtToken1;

methods {
    function _.transferFrom(address from, address to, uint256 amount) external with (env e)
        => transferFromSumm(e, calledContract, from, to, amount) expect bool UNRESOLVED;
    function _.transfer(address to, uint256 amount) external with (env e)
        => transferSumm(e, calledContract, to, amount) expect bool UNRESOLVED;
    function _.totalSupply() external => totalSupplySumm(calledContract) expect uint256 UNRESOLVED;
    function _.balanceOf(address account) external => balanceOfSumm(calledContract, account) expect uint256 UNRESOLVED;

    // share token 1
    function shareCollateralToken1.balanceOf(address) external returns(uint256) envfree;
    function shareCollateralToken1.totalSupply() external returns(uint256) envfree;
    function shareProtectedCollateralToken1.balanceOf(address) external returns(uint256) envfree;
    function shareProtectedCollateralToken1.totalSupply() external returns(uint256) envfree;
    function shareDebtToken1.balanceOf(address) external returns(uint256) envfree;
    function shareDebtToken1.totalSupply() external returns(uint256) envfree;
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
    } else if (callee == shareCollateralToken1) {
        require totalSupply == shareCollateralToken1.totalSupply();
    } else if (callee == shareProtectedCollateralToken1) {
        require totalSupply == shareProtectedCollateralToken1.totalSupply();
    } else if (callee == shareDebtToken1) {
        require totalSupply == shareDebtToken1.totalSupply();
    } else {
        assert false, "Unresolved call to ERC-20 totalSupply()";
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
    } else if (callee == shareCollateralToken1) {
        require balanceOfAccount == shareCollateralToken1.balanceOf(account);
    } else if (callee == shareProtectedCollateralToken1) {
        require balanceOfAccount == shareProtectedCollateralToken1.balanceOf(account);
    } else if (callee == shareDebtToken1) {
        require balanceOfAccount == shareDebtToken1.balanceOf(account);
    } else if (callee == token0) {
        require balanceOfAccount == token0.balanceOf(account);
    } else {
       assert false, "Unresolved call to ERC-20 balanceOf(address)";
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
    } else if (callee == shareCollateralToken1) {
        require success == shareCollateralToken1.transferFrom(e, from, to, amount);
    } else if (callee == shareProtectedCollateralToken1) {
        require success == shareProtectedCollateralToken1.transferFrom(e, from, to, amount);
    } else if (callee == shareDebtToken1) {
        require success == shareDebtToken1.transferFrom(e, from, to, amount);
    } else if(callee == token0) {
        require success == token0.transferFrom(e, from, to, amount);
    } else {
        assert false, "Unresolved call to ERC-20 transferFrom(address,address,address,uint256)";
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
    } else if (callee == shareCollateralToken1) {
        require success == shareCollateralToken1.transfer(e, to, amount);
    } else if (callee == shareProtectedCollateralToken1) {
        require success == shareProtectedCollateralToken1.transfer(e, to, amount);
    } else if (callee == shareDebtToken1) {
        require success == shareDebtToken1.transfer(e, to, amount);
    } else if(callee == token0) {
        require success == token0.transfer(e, to, amount);
    } else {
        assert false, "Unresolved call to ERC-20 transfer(address,address,uint256)";
    }

    return success;
}
