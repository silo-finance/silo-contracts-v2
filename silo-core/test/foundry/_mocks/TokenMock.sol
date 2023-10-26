// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {LocalVm} from "../_common/LocalVm.sol";

contract TokenMock is LocalVm {
    address public immutable ADDRESS;

    constructor(address _token) {
        ADDRESS = _token == address(0) ? address(0x5224928173683243804202752353186) : _token;
    }

    function balanceOfMock(address _owner, uint256 _balance) public {
        _vm.mockCall(
            ADDRESS,
            abi.encodeWithSelector(IERC20Upgradeable.balanceOf.selector, _owner),
            abi.encode(_balance)
        );
    }

    function transferFromMock(address _from, address _to, uint256 _amount) public {
        require(_from != address(0), "ERC20: transfer from the zero address");
        require(_to != address(0), "ERC20: transfer to the zero address");

        _vm.mockCall(
            ADDRESS,
            abi.encodeWithSelector(IERC20Upgradeable.transferFrom.selector, _from, _to, _amount),
            abi.encode(true)
        );
    }

    function transferMock(address _to, uint256 _amount) public {
        require(_to != address(0), "ERC20: transfer to the zero address");

        _vm.mockCall(
            ADDRESS,
            abi.encodeWithSelector(IERC20Upgradeable.transfer.selector, _to, _amount),
            abi.encode(true)
        );
    }

    function totalSupplyMock(uint256 _totalSupply) external {
        _vm.mockCall(
            ADDRESS,
            abi.encodeWithSelector(IERC20Upgradeable.totalSupply.selector),
            abi.encode(_totalSupply)
        );
    }

    function decimalsMock(uint256 _decimals) external {
        _vm.mockCall(
            ADDRESS,
            abi.encodeWithSelector(bytes4(keccak256("decimals()"))),
            abi.encode(_decimals)
        );
    }

    function mintMock(address _owner, address _spender, uint256 _amount) external {
        require(_owner != address(0), "ERC20: mint to the zero address");

        _vm.mockCall(
            ADDRESS,
            abi.encodeWithSelector(IShareToken.mint.selector, _owner, _spender, _amount),
            abi.encode()
        );
    }
}
