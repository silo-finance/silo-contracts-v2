// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISiloLiquidation} from "silo-core/contracts/interfaces/ISiloLiquidation.sol";

import {MintableToken} from "./MintableToken.sol";
import {SiloFixture, SiloConfigOverride} from "./fixtures/SiloFixture.sol";
import {CommonBase} from "forge-std/Base.sol";

abstract contract SiloLittleHelper is CommonBase {
    MintableToken token0;
    MintableToken token1;

    ISilo silo0;
    ISilo silo1;
    ISiloLiquidation siloLiquidation;

    function __init(MintableToken _token0, MintableToken _token1, ISilo _silo0, ISilo _silo1) internal {
        token0 = _token0;
        token1 = _token1;
        silo0 = _silo0;
        silo1 = _silo1;
    }

    function _setUpLocalFixture() internal returns (ISiloConfig siloConfig) {
        return _localFixture("");
    }

    function _setUpLocalFixture(string memory _configName) internal returns (ISiloConfig siloConfig) {
        return _localFixture(_configName);
    }

    function _depositForBorrowRevert(uint256 _assets, address _depositor, bytes4 _error) internal {
        _depositForBorrowRevert(_assets, _depositor, _error);
    }

    function _depositForBorrowRevert(uint256 _assets, address _depositor, ISilo.AssetType _type, bytes4 _error) internal {
        _mintTokens(token1, _assets, _depositor);

        vm.startPrank(_depositor);
        token1.approve(address(silo1), _assets);

        vm.expectRevert(_error);
        silo1.deposit(_assets, _depositor, _type);
        vm.stopPrank();
    }

    function _depositForBorrow(uint256 _assets, address _depositor) internal returns (uint256 shares) {
        return _makeDeposit(silo1, token1, _assets, _depositor, ISilo.AssetType.Collateral);
    }

    function _deposit(uint256 _assets, address _depositor, ISilo.AssetType _type) internal returns (uint256 shares) {
        return _makeDeposit(silo0, token0, _assets, _depositor, _type);
    }

    function _deposit(uint256 _assets, address _depositor) internal returns (uint256 shares) {
        return _makeDeposit(silo0, token0, _assets, _depositor, ISilo.AssetType.Collateral);
    }

    function _mint(uint256 _approve, uint256 _shares, address _depositor) internal returns (uint256 assets) {
        return _makeMint(_approve, silo0, token0, _shares, _depositor, ISilo.AssetType.Collateral);
    }

    function _mintForBorrow(uint256 _approve, uint256 _shares, address _depositor) internal returns (uint256 assets) {
        return _makeMint(_approve, silo1, token1, _shares, _depositor, ISilo.AssetType.Collateral);
    }

    function _borrow(uint256 _amount, address _borrower) internal returns (uint256 shares) {
        vm.prank(_borrower);
        shares = silo1.borrow(_amount, _borrower, _borrower);
    }

    function _borrowShares(uint256 _shares, address _borrower) internal returns (uint256 amount) {
        vm.prank(_borrower);
        amount = silo1.borrowShares(_shares, _borrower, _borrower);
    }

    function _repay(uint256 _amount, address _borrower) internal returns (uint256 shares) {
        _mintTokens(token1, _amount, _borrower);
        vm.prank(_borrower);
        token1.approve(address(silo1), _amount);
        vm.prank(_borrower);

        shares = silo1.repay(_amount, _borrower);
    }

    function _repayShares(uint256 _approval, uint256 _shares, address _borrower)
        internal
        returns (uint256 shares)
    {
        return _repayShares(_approval, _shares, _borrower, bytes(""));
    }

    function _repayShares(uint256 _approval, uint256 _shares, address _borrower, bytes memory _revert)
        internal
        returns (uint256 shares)
    {
        _mintTokens(token1, _approval, _borrower);
        vm.prank(_borrower);
        token1.approve(address(silo1), _approval);
        vm.prank(_borrower);

        if (_revert.length != 0) {
            vm.expectRevert(_revert);
        }

        shares = silo1.repayShares(_shares, _borrower);
    }

    function _redeem(uint256 _amount, address _depositor) internal returns (uint256 assets) {
        vm.prank(_depositor);
        return silo0.redeem(_amount, _depositor, _depositor);
    }

    function _withdraw(uint256 _amount, address _depositor) internal returns (uint256 assets){
        vm.prank(_depositor);
        return silo0.withdraw(_amount, _depositor, _depositor);
    }

    function _withdraw(uint256 _amount, address _depositor, ISilo.AssetType _type) internal returns (uint256 assets){
        vm.prank(_depositor);
        return silo0.withdraw(_amount, _depositor, _depositor, _type);
    }

    function _makeDeposit(ISilo _silo, MintableToken _token, uint256 _assets, address _depositor, ISilo.AssetType _type)
        internal
        returns (uint256 shares)
    {
        _mintTokens(_token, _assets, _depositor);

        vm.startPrank(_depositor);
        _token.approve(address(_silo), _assets);
        shares = _silo.deposit(_assets, _depositor, _type);
        vm.stopPrank();
    }

    function _makeMint(
        uint256 _approve,
        ISilo _silo,
        MintableToken _token,
        uint256 _shares,
        address _depositor,
        ISilo.AssetType _type
    )
        internal
        returns (uint256 assets)
    {
        _mintTokens(_token, _approve, _depositor);

        vm.startPrank(_depositor);
        _token.approve(address(_silo), _approve);
        assets = _silo.mint(_shares, _depositor, _type);
        vm.stopPrank();
    }

    function _mintTokens(MintableToken _token, uint256 _assets, address _user) internal {
        uint256 balanceOf = _token.balanceOf(_user);

        if (balanceOf < _assets) {
            uint256 toMint = _assets - balanceOf;
            _token.mint(_user, toMint);
        }
    }

    function _createDebt(uint128 _amount, address _borrower) internal returns (uint256 debtShares){
        _depositForBorrow(_amount, address(0x987654321));
        _deposit(uint256(_amount) * 2 + (_amount % 2), _borrower);
        debtShares = _borrow(_amount, _borrower);
    }

    function _localFixture(string memory _configName)
        private
        returns (ISiloConfig siloConfig)
    {
        token0 = new MintableToken(18);
        token1 = new MintableToken(18);

        SiloConfigOverride memory overrides;
        overrides.token0 = address(token0);
        overrides.token1 = address(token1);
        overrides.configName = _configName;

        SiloFixture siloFixture = new SiloFixture();
        (siloConfig, silo0, silo1,,) = siloFixture.deploy_local(overrides);
        siloLiquidation = ISiloLiquidation(siloConfig.getConfig(address(silo0)).liquidation);
    }
}
