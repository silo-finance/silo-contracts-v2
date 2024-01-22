methods {
    function Token0.transferFrom(address _from, address _to, uint256 _amount)
        external
        returns (bool) => simplified_transferFrom(_from, _to, _amount);

    function Token0.transfer(address _to, uint256 _amount)
        external
        returns (bool) => simplified_transfer(_to, _amount);
}

ghost simplified_transferFrom(address, address, uint256) returns bool;

ghost simplified_transfer(address, uint256) returns bool;
