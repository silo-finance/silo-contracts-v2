// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

abstract contract MadeByFactory {
    mapping(address deployedOracle => bool isMade) public madeByFactory;

    event NewOracle(address indexed oracle);

    error NewOracleZero();
    error ExistingAddress();

    /// @dev execute this method from target factory, to save deployment
    /// @param _newOracle new oracle address
    function _saveOracle(address _newOracle) internal virtual {
        require(_newOracle != address(0), NewOracleZero());
        require(!madeByFactory[_newOracle], ExistingAddress());

        madeByFactory[_newOracle] = true;

        emit NewOracle(_newOracle);
    }
}
