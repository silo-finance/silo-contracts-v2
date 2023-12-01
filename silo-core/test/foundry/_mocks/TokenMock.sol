// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {CommonBase} from "forge-std/Base.sol";

contract TokenMock is CommonBase {
    address public immutable ADDRESS;

    constructor(address _token) {
        ADDRESS = _token == address(0) ? address(0x5224928173683243804202752353186) : _token;
    }

    // IERC20Upgradeable.balanceOf.selector: 0x70a08231
    function balanceOfMock(address _owner, uint256 _balance, bool _expectCall) public {
        bytes memory data = abi.encodeWithSelector(IERC20Upgradeable.balanceOf.selector, _owner);
        vm.mockCall(ADDRESS, data, abi.encode(_balance));

        if (_expectCall) {
            vm.expectCall(ADDRESS, data);
        }
    }

    function balanceOfMock(address _owner, uint256 _balance) public {
        balanceOfMock(_owner, _balance, true);
    }

    function transferFromMock(address _from, address _to, uint256 _amount) public {
        require(_from != address(0), "ERC20: transfer from the zero address");
        require(_to != address(0), "ERC20: transfer to the zero address");

        bytes memory data = abi.encodeWithSelector(IERC20Upgradeable.transferFrom.selector, _from, _to, _amount);
        vm.mockCall(ADDRESS, data, abi.encode(true));
        vm.expectCall(ADDRESS, data);
    }

    // IERC20Upgradeable.transfer.selector: 0xa9059cbb
    function transferMock(address _to, uint256 _amount) public {
        require(_to != address(0), "ERC20: transfer to the zero address");

        bytes memory data = abi.encodeWithSelector(IERC20Upgradeable.transfer.selector, _to, _amount);
        vm.mockCall(ADDRESS, data, abi.encode(true));
        vm.expectCall(ADDRESS, data);
    }

    // IERC20Upgradeable.totalSupply.selector: 0x18160ddd
    function totalSupplyMock(uint256 _totalSupply, bool _expectCall) public {
        bytes memory data = abi.encodeWithSelector(IERC20Upgradeable.totalSupply.selector);
        vm.mockCall(ADDRESS, data, abi.encode(_totalSupply));

        if (_expectCall) {
            vm.expectCall(ADDRESS, data);
        }
    }

    function totalSupplyMock(uint256 _totalSupply) external {
        totalSupplyMock(_totalSupply, true);
    }

    function decimalsMock(uint256 _decimals) external {
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256("decimals()")));
        vm.mockCall(ADDRESS, data, abi.encode(_decimals));
        vm.expectCall(ADDRESS, data);
    }

    // IShareToken.mint.selector: 0xc6c3bbe6
    function mintMock(address _owner, address _spender, uint256 _amount) external {
        require(_owner != address(0), "ERC20: mint to the zero address");

        bytes memory data = abi.encodeWithSelector(IShareToken.mint.selector, _owner, _spender, _amount);
        vm.mockCall(ADDRESS, data, abi.encode());
        vm.expectCall(ADDRESS, data);
    }
}
