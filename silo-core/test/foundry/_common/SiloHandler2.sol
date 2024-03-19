// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloLensLib} from "silo-core/contracts/lens/lib/SiloLensLib.sol";

import {MintableToken} from "../_common/MintableToken.sol";

// TODO make all ...possible methods in a way, that we can turn ON: forge-config: core.invariant.fail-on-revert = true
contract SiloHandler2 is Test {
    using SiloLensLib for ISilo;

    ISilo public immutable SILO_0;
    ISilo public immutable SILO_1;

    MintableToken immutable token0;
    MintableToken immutable token1;

    address user1 = makeAddr("User 1");
    address user2 = makeAddr("User 2");
    address user3 = makeAddr("User 3");

    constructor(ISilo _silo0, ISilo _silo1, MintableToken _token0, MintableToken _token1) {
        SILO_0 = _silo0;
        SILO_1 = _silo1;
        token0 = _token0;
        token1 = _token1;

        token0.setOnDemand(true);
        token1.setOnDemand(true);
    }

    function toTheFuture(uint24 _time) external {
        vm.warp(_time);
    }

    function deposit(bool _pickSilo0, uint256 _assets) external {
        ISilo silo = _pickSilo(_pickSilo0);

        (_assets, ) = _depositPossible(silo, _assets, uint8(ISilo.AssetType.Collateral));
        vm.assume(_assets > 0);

        vm.prank(msg.sender);
        silo.deposit(_assets, msg.sender);
    }

    function depositType(bool _pickSilo0, uint256 _assets, ISilo.AssetType _assetType) external {
        assertTrue(false, "[depositType] should not call!!");
        ISilo silo = _pickSilo(_pickSilo0);

        (_assets, _assetType) = _depositPossible(silo, _assets, uint8(_assetType));
        vm.assume(_assets > 0);

        vm.prank(msg.sender);
        silo.deposit(_assets, msg.sender, _assetType);
    }

    function withdraw(bool _pickSilo0, uint256 _assets) external {
        assertTrue(false, "[withdraw] should not call!!");
        ISilo silo = _pickSilo(_pickSilo0);

        vm.assume(_withdrawPossible(silo, _assets, uint8(ISilo.AssetType.Collateral)));

        vm.prank(msg.sender);
        silo.withdraw(_assets, msg.sender, msg.sender);
    }

    function withdrawType(bool _pickSilo0, uint256 _assets, ISilo.AssetType _assetType) external {
        assertTrue(false, "[withdrawType] should not call!!");
        ISilo silo = _pickSilo(_pickSilo0);

        vm.assume(_withdrawPossible(silo, _assets, uint8(_assetType)));

        vm.prank(msg.sender);
        silo.withdraw(_assets, msg.sender, msg.sender, _assetType);
    }

    function borrow(bool _pickSilo0, uint256 _assets) external {
        assertTrue(false, "[borrow] should not call!!");
        ISilo silo = _pickSilo(_pickSilo0);

        vm.assume(_borrowPossible(silo, _assets));

        vm.prank(msg.sender);
        silo.borrow(_assets, msg.sender, msg.sender);
    }

    function repay(bool _pickSilo0, uint256 _assets) external {
        assertTrue(false, "[repay] should not call!!");
        ISilo silo = _pickSilo(_pickSilo0);
        vm.assume(_repayPossible(silo, _assets));

        vm.prank(msg.sender);
        silo.repay(_assets, msg.sender);
    }

    function _depositPossible(ISilo _silo, uint256 _assets, uint8 _type)
        internal
        view
        returns (uint256 assets, ISilo.AssetType assetType)
    {
        if (!_silo.depositPossible(msg.sender)) {
            // do not execute invariant
            return (0, ISilo.AssetType.Collateral);
        }

        assetType = ISilo.AssetType(bound(_type, 1, 2));

        uint256 balanceOf = _token(_silo).balanceOf(msg.sender);

        if (balanceOf >= _assets) return (_assets, assetType);

        uint256 toMint = _assets - balanceOf;
        uint256 maxMint = type(uint256).max - _token(_silo).totalSupply();

        if (maxMint == 0) return (0, ISilo.AssetType.Collateral);

        if (toMint > maxMint) {
            // overflow, limit the input
            assets = bound(_assets, 1, balanceOf + maxMint);
        }
    }

    function _withdrawPossible(ISilo _silo, uint256 _assets, uint8 _type) internal view returns (bool) {
        if (_token(_silo).balanceOf(address(_silo)) == 0) {
            // nobody deposit
            return false;
        }

        vm.assume(_assets > 0);
        _type = uint8(bound(_type, 1, 2));

        (address protectedShareToken, address collateralShareToken, ) = _silo.config().getShareTokens(address(_silo));

        uint256 userSharesBalance = _type == uint8(ISilo.AssetType.Collateral)
            ? IShareToken(collateralShareToken).balanceOf(msg.sender)
            : IShareToken(protectedShareToken).balanceOf(msg.sender);

        uint256 toShares = _silo.convertToShares(_assets);

        if (toShares > userSharesBalance) {
            // user do not have that much shares
            _assets = bound(_assets, 1, _silo.convertToAssets(userSharesBalance));
        }

        return true;
    }

    function _borrowPossible(ISilo _silo, uint256 _assets) internal view returns (bool) {
        if (_token(_silo).balanceOf(address(_silo)) == 0) {
            // nobody deposit
            return false;
        }

        vm.assume(_assets > 0);

        if (!_silo.borrowPossible(msg.sender)) {
            return false;
        }

        _assets = bound(_assets, 1, _silo.maxBorrow(msg.sender));

        return true;
    }

    function _repayPossible(ISilo _silo, uint256 _assets) internal view returns (bool) {
        (,, address debtShareToken) = _silo.config().getShareTokens(address(_silo));

        uint256 debtShares = IShareToken(debtShareToken).balanceOf(address(msg.sender));

        if (debtShares == 0) {
            // no debt
            return false;
        }

        _assets = bound(_assets, 1, _silo.previewRepayShares(debtShares));

        return true;
    }

    function _pickSilo(bool _pickSilo0) internal view returns (ISilo) {
        return _pickSilo0 ? SILO_0 : SILO_1;
    }

    function _token(ISilo _silo) internal view returns (MintableToken) {
        return MintableToken(_silo.config().getConfig(address(_silo)).token);
    }
}
