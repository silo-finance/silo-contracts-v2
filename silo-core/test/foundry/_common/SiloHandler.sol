// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {MintableToken} from "../_common/MintableToken.sol";

contract SiloHandler is Test {
    ISilo public immutable SILO_0;
    ISilo public immutable SILO_1;

    MintableToken immutable token0;
    MintableToken immutable token1;

    constructor(ISilo _silo0, ISilo _silo1, MintableToken _token0, MintableToken _token1) {
        SILO_0 = _silo0;
        SILO_1 = _silo1;
        token0 = _token0;
        token1 = _token1;
    }

    function mint(uint128 _shares) external {
        if (!_depositPossible(_shares, uint8(ISilo.AssetType.Collateral))) {
            // do not execute invariant
            return;
        }

        vm.prank(msg.sender);
        token0.approve(address(SILO_0), _shares);

        vm.prank(msg.sender);
        SILO_0.mint(_shares, msg.sender);
    }

    function deposit(uint128 _assets) external {
        vm.assume(_depositPossible(_assets, uint8(ISilo.AssetType.Collateral)));

        vm.prank(msg.sender);
        token0.approve(address(SILO_0), _assets);

        vm.prank(msg.sender);
        SILO_0.deposit(_assets, msg.sender);
    }

    function depositType(uint128 _assets, ISilo.AssetType _assetType) external {
        vm.assume(_depositPossible(_assets, uint8(ISilo.AssetType.Collateral)));

        vm.prank(msg.sender);
        token0.approve(address(SILO_0), _assets);

        vm.prank(msg.sender);
        SILO_0.deposit(_assets, msg.sender, _assetType);
    }

    function withdraw(uint256 _assets) external {
        vm.assume(_withdrawPossible(_assets, uint8(ISilo.AssetType.Collateral)));

        vm.prank(msg.sender);
        SILO_0.withdraw(_assets, msg.sender, msg.sender);
    }

    function withdrawType(uint256 _assets, ISilo.AssetType _assetType) external {
        vm.assume(_withdrawPossible(_assets, uint8(_assetType)));

        vm.prank(msg.sender);
        SILO_0.withdraw(_assets, msg.sender, msg.sender, _assetType);
    }


    function borrow(uint256 _assets) external {
        vm.assume(_borrowPossible(_assets));

        vm.prank(msg.sender);
        SILO_1.borrow(_assets, msg.sender, msg.sender);
    }

    function _depositPossible(uint256 _assets, uint8 _type) internal returns (bool) {
        _assets = bound(_assets, 1, 2 ** 128 - 1);

        if (!SILO_0.depositPossible(msg.sender)) {
            // do not execute invariant
            return false;
        }

        _type = uint8(bound(_type, 1, 2));

        uint256 balanceOf = token0.balanceOf(msg.sender);

        if (balanceOf < _assets) {
            uint256 toMint = _assets - balanceOf;
            uint256 maxMint = type(uint256).max - token0.totalSupply();

            if (toMint > maxMint) {
                // overflow, limit the input
                _assets = bound(_assets, 1, balanceOf + maxMint);
            }

            token0.mint(msg.sender, toMint);
        }

        return true;
    }

    function _withdrawPossible(uint256 _assets, uint8 _type) internal view returns (bool) {
        if (token0.balanceOf(address(SILO_0)) == 0) {
            // nobody deposit
            return false;
        }

        vm.assume(_assets > 0);
        _type = uint8(bound(_type, 1, 2));

        (address protectedShareToken, address collateralShareToken, ) = SILO_0.config().getShareTokens(address(SILO_0));

        uint256 userSharesBalance = _type == uint8(ISilo.AssetType.Collateral)
            ? IShareToken(collateralShareToken).balanceOf(msg.sender)
            : IShareToken(protectedShareToken).balanceOf(msg.sender);

        uint256 toShares = SILO_0.convertToShares(_assets);

        if (toShares > userSharesBalance) {
            // user do not have that much shares
            _assets = bound(_assets, 1, SILO_0.convertToAssets(userSharesBalance));
        }

        return true;
    }


    function _borrowPossible(uint256 _assets) internal view returns (bool) {
        if (token1.balanceOf(address(SILO_1)) == 0) {
            // nobody deposit
            return false;
        }

        vm.assume(_assets > 0);

        if (!SILO_1.borrowPossible(msg.sender)) {
            return false;
        }

        _assets = bound(_assets, 1, SILO_1.maxBorrow(msg.sender));

        return true;
    }
}
