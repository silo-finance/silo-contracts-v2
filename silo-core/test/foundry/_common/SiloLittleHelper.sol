// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {MintableToken} from "./MintableToken.sol";

abstract contract SiloLittleHelper {
    Vm _vm;

    MintableToken token0;
    MintableToken token1;

    ISilo silo0;
    ISilo silo1;

    function __init(
        Vm __vm,
        MintableToken _token0, MintableToken _token1, ISilo _silo0, ISilo _silo1
    ) internal {
        _vm = __vm;
        token0 = _token0;
        token1 = _token1;
        silo0 = _silo0;
        silo1 = _silo1;
    }

    function _depositForBorrow(uint256 _assets, address _depositor) internal {
        _makeDeposit(silo1, token1, _assets, _depositor, ISilo.AssetType.Collateral);
    }

    function _deposit(uint256 _assets, address _depositor, ISilo.AssetType _type) internal {
        _makeDeposit(silo0, token0, _assets, _depositor, _type);
    }

    function _deposit(uint256 _assets, address _depositor) internal {
        _makeDeposit(silo0, token0, _assets, _depositor, ISilo.AssetType.Collateral);
    }

    function _borrow(uint256 _amount, address _borrower) internal returns (uint256 shares) {
        _vm.prank(_borrower);
        shares = silo1.borrow(_amount, _borrower, _borrower);
    }

    function _withdraw(uint256 _amount, address _depositor) internal returns (uint256 assets){
        _vm.prank(_depositor);
        return silo0.withdraw(_amount, _depositor, _depositor);
    }

    function _withdraw(uint256 _amount, address _depositor, ISilo.AssetType _type) internal returns (uint256 assets){
        _vm.prank(_depositor);
        return silo0.withdraw(_amount, _depositor, _depositor, _type);
    }

    function _makeDeposit(ISilo _silo, MintableToken _token, uint256 _assets, address _depositor, ISilo.AssetType _type)
        internal
    {
        uint256 balanceOf = _token.balanceOf(_depositor);

        if (balanceOf < _assets) {
            uint256 toMint = _assets - balanceOf;
            _token.mint(_depositor, toMint);
        }

        _vm.prank(_depositor);
        _token.approve(address(_silo), _assets);
        _vm.prank(_depositor);
        _silo.deposit(_assets, _depositor, _type);
    }
}
