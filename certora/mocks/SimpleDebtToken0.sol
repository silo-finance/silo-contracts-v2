// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {SimpleERC20} from "./SimpleERC20.sol";



contract SimpleDebtToken0 is SimpleERC20 {


    address public SILO;

    modifier onlySilo() {
        require(msg.sender == SILO, "OnlySilo");
        _;
    }

    function transfer(
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        uint256 currentAllowance = _allowances[_recipient][msg.sender];
        require(currentAllowance >= _amount);
        _transfer(msg.sender,_recipient, _amount);
        _allowances[_recipient][msg.sender] -= _amount;
        return true;
    }

    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        uint256 currentAllowance = _allowances[_recipient][msg.sender];
        require(currentAllowance >= _amount);
        _transfer(_sender,_recipient, _amount);
        _allowances[_recipient][msg.sender] -= _amount;
        return true;
    }
 
    function burn(address _owner, address /* _spender */, uint256 _amount) external onlySilo {
        _burn(_owner, _amount);
    }

    function mint(address _owner, address _spender, uint256 _amount) external onlySilo {
        if (_owner != _spender) {
            uint256 currentAllowance = _allowances[_owner][_spender];
            require(currentAllowance >= _amount);
            _allowances[_owner][_spender] -= _amount;
        }
        _mint(_owner, _amount);
    }



}