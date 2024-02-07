methods {
    function _.name() external => simplified_name() expect string UNRESOLVED;
    function _.symbol() external => simplified_symbol() expect string UNRESOLVED;
    function _.forwardTransfer(address _owner, address _recipient, uint256 _amount) external with (env e)
        => summForwardTransfer(e, calledContract, _owner, _recipient, _amount) expect void UNRESOLVED;
    function _.forwardTransferFrom(address _spender, address _from, address _to, uint256 _amount) external with (env e)
        => summForwardTransferFrom(e, calledContract, _spender, _from, _to, _amount) expect void UNRESOLVED;
    function _.forwardApprove(address _owner, address _spender, uint256 _amount) external with (env e)
        => summForwardApprove(e, calledContract, _owner, _spender, _amount) expect void UNRESOLVED;
        function _.mint(address _owner, address _spender, uint256 _amount) external with (env e)
        => mintSumm(e, calledContract, _owner, _spender, _amount) expect void UNRESOLVED;
    function _.burn(address _owner, address _spender, uint256 _amount) external with (env e)
        => burnSumm(e, calledContract, _owner, _spender, _amount) expect void UNRESOLVED;
}

function simplified_name() returns string {
    return "n";
}

function simplified_symbol() returns string {
    return "s";
}

function mintSumm(env e, address callee, address _owner, address _spender, uint256 _amount) {
    if(callee == shareCollateralToken0) {
        shareCollateralToken0.mint(e, _owner, _spender, _amount);
    } else if(callee == shareProtectedCollateralToken0) {
        shareProtectedCollateralToken0.mint(e, _owner, _spender, _amount);
    } else if (callee == shareDebtToken0) {
        shareDebtToken0.mint(e, _owner, _spender, _amount);
    } else {
        assert false, "Unresolved call to share token mint(address,address,uint256)";
    }
}

function burnSumm(env e, address callee, address _owner, address _spender, uint256 _amount) {
    if(callee == shareCollateralToken0) {
        shareCollateralToken0.burn(e, _owner, _spender, _amount);
    } else if(callee == shareProtectedCollateralToken0) {
        shareProtectedCollateralToken0.burn(e, _owner, _spender, _amount);
    } else if (callee == shareDebtToken0) {
        shareDebtToken0.burn(e, _owner, _spender, _amount);
    } else {
        assert false, "Unresolved call to share token burn(address,address,uint256)";
    }
}

function summForwardTransfer(env e, address callee, address _owner, address _recipient, uint256 _amount) {
    if(callee == shareCollateralToken0) {
        shareCollateralToken0.forwardTransfer(e, _owner, _recipient, _amount);
    } else if(callee == shareProtectedCollateralToken0) {
        shareProtectedCollateralToken0.forwardTransfer(e, _owner, _recipient, _amount);
    } else if (callee == shareDebtToken0) {
        shareDebtToken0.forwardTransfer(e, _owner, _recipient, _amount);
    } else {
        assert false, "Unresolved call to share token forwardTransfer(address,address,uint256)";
    }
}

function summForwardTransferFrom(env e, address callee, address _spender, address _from, address _to, uint256 _amount) {
    if(callee == shareCollateralToken0) {
        shareCollateralToken0.forwardTransferFrom(e, _spender, _from, _to, _amount);
    } else if(callee == shareProtectedCollateralToken0) {
        shareProtectedCollateralToken0.forwardTransferFrom(e, _spender, _from, _to, _amount);
    } else if (callee == shareDebtToken0) {
        shareDebtToken0.forwardTransferFrom(e, _spender, _from, _to, _amount);
    } else {
        assert false, "Unresolved call to share token forwardTransferFrom(address,address,address,uint256)";
    }
}

function summForwardApprove(env e, address callee, address _owner, address _spender, uint256 _amount) {
    if(callee == shareCollateralToken0) {
        shareCollateralToken0.forwardApprove(e, _owner, _spender, _amount);
    } else if(callee == shareProtectedCollateralToken0) {
        shareProtectedCollateralToken0.forwardApprove(e, _owner, _spender, _amount);
    } else if (callee == shareDebtToken0) {
        shareDebtToken0.forwardApprove(e, _owner, _spender, _amount);
    } else {
        assert false, "Unresolved call to share token forwardApprove(address,address,uint256)";
    }
}
