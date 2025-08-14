// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {SimpleERC20} from "./SimpleERC20.sol";



contract SimpleCollateralToken0 is SimpleERC20 {


    address public SILO;

    modifier onlySilo() {
        require(msg.sender == SILO, "OnlySilo");
        _;
    }
 
    function mint(address _owner, address /* _spender */, uint256 _amount) external onlySilo {
        _mint(_owner, _amount);
    }

    function burn(address _owner, address _spender, uint256 _amount) external onlySilo {
        if (_owner != _spender) {
            uint256 currentAllowance = _allowances[_owner][_spender];
            require(currentAllowance >= _amount);
            _allowances[_owner][_spender] -= _amount;
        }
        _burn(_owner, _amount);

    }



}