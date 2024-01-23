methods {
    function _.forwardTransfer(address,address,uint256) external => DISPATCHER(true);
    function _.forwardTransferFrom(address,address,address,uint256) external => DISPATCHER(true);
    function _.forwardApprove(address,address,uint256) external => DISPATCHER(true);

    function allowance(address,address) external returns(uint) envfree;
    function balanceOf(address) external returns(uint) envfree;
    function totalSupply() external returns(uint) envfree;
}

function simplified_name() returns string {
    return "n";
}

function simplified_symbol() returns string {
    return "s";
}
