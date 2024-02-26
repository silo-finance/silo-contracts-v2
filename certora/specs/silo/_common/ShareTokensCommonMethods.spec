methods {
    function _.forwardTransfer(address _owner, address _recipient, uint256 _amount) external => DISPATCHER(false);
    
    function _.forwardTransferFrom(address _spender, address _from, address _to, uint256 _amount) external => DISPATCHER(false);
    
    function _.forwardApprove(address _owner, address _spender, uint256 _amount) external => DISPATCHER(false);
}