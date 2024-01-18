methods {
    function _.forwardTransfer(address,address,uint256) external => DISPATCHER(true);
    function _.forwardTransferFrom(address,address,address,uint256) external => DISPATCHER(true);
    function _.forwardApprove(address,address,uint256) external => DISPATCHER(true);
}

function simplified_name() returns string {
    return "n";
}

function simplified_symbol() returns string {
    return "s";
}
