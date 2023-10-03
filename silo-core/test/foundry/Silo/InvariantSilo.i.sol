// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {TokenMock} from "silo-core/test/foundry/_mocks/TokenMock.sol";
import {SiloFixture} from "../_common/fixtures/SiloFixture.sol";

import "../_common/MintableToken.sol";


contract SiloHandler is Test {
    ISilo public immutable SILO;
    MintableToken token0;

    constructor(ISilo _silo, MintableToken _token0) {
        SILO = _silo;
        token0 = _token0;
    }

    function mint(uint256 _shares) external {
        if (!_depositPossible(_shares, uint8(ISilo.AssetType.Collateral))) {
            // do not execute invariant
            return;
        }

        vm.prank(msg.sender);
        token0.approve(address(SILO), _shares);

        vm.prank(msg.sender);
        SILO.mint(_shares, msg.sender);
    }

    function deposit(uint256 _assets) external {
        if (!_depositPossible(_assets, uint8(ISilo.AssetType.Collateral))) {
            // do not execute invariant
            return;
        }

        vm.prank(msg.sender);
        token0.approve(address(SILO), _assets);

        vm.prank(msg.sender);
        SILO.deposit(_assets, msg.sender);
    }

    function depositType(uint256 _assets, ISilo.AssetType _assetType) external {
        if (!_depositPossible(_assets, uint8(_assetType))) {
            // do not execute invariant
            return;
        }

        vm.prank(msg.sender);
        token0.approve(address(SILO), _assets);

        vm.prank(msg.sender);
        SILO.deposit(_assets, msg.sender, _assetType);
    }

    function withdraw(uint256 _assets) external {
        if (!_withdrawPossible(_assets, uint8(ISilo.AssetType.Collateral))) return;

        vm.prank(msg.sender);
        SILO.withdraw(_assets, msg.sender, msg.sender);
    }

    function withdrawType(uint256 _assets, ISilo.AssetType _assetType) external {
        if (!_withdrawPossible(_assets, uint8(_assetType))) return;

        vm.prank(msg.sender);
        SILO.withdraw(_assets, msg.sender, msg.sender);
    }

    function _depositPossible(uint256 _assets, uint8 _type) internal returns (bool) {
        if (!SILO.depositPossible(msg.sender)) {
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
        if (token0.balanceOf(address(SILO)) == 0) {
            // nobody deposit
            return false;
        }

        _type = uint8(bound(_type, 1, 2));

        (address protectedShareToken, address collateralShareToken, ) = SILO.config().getShareTokens(address(SILO));

        uint256 userSharesBalance = _type == uint8(ISilo.AssetType.Collateral)
            ? IShareToken(collateralShareToken).balanceOf(msg.sender)
            : IShareToken(protectedShareToken).balanceOf(msg.sender);

        uint256 toShares = SILO.convertToShares(_assets);

        if (toShares > userSharesBalance) {
            // user do not have that much shares
            _assets = bound(_assets, 1, SILO.convertToAssets(userSharesBalance));
        }

        return true;
    }
}

/*
    forge test -vv --mc WithdrawWhenNoDebtTest
*/
contract InvariantSiloTest is Test {
    ISiloConfig siloConfig;
    ISilo silo0;
    ISilo silo1;

    MintableToken token0;
    MintableToken token1;

    SiloHandler internal siloHandler;

    function setUp() public {
        token0 = new MintableToken();
        token1 = new MintableToken();

        SiloFixture siloFixture = new SiloFixture();
        (siloConfig, silo0, silo1,,) = siloFixture.deploy_local(SiloFixture.Override(address(token0), address(token1)));

        siloHandler = new SiloHandler(silo0, token0);
//        bytes4[] memory selectors = new bytes4[](5);
//        selectors[0] = DepositForwarder.deposit.selector;
//        selectors[1] = DepositForwarder.depositType.selector;
//        selectors[2] = DepositForwarder.mint.selector;
//        selectors[3] = DepositForwarder.withdraw.selector;
//        selectors[4] = DepositForwarder.withdrawType.selector;

        targetContract(address(siloHandler));

//        targetSelector(FuzzSelector(address(forwarder), selectors));

        targetSender(address(0xabc01));
        targetSender(address(0xabc02));
        targetSender(address(0xabc03));
    }

    /*
    forge test -vv --mt invariant_silo_deposit
    */
    /// forge-config: core.invariant.runs = 10
    /// forge-config: core.invariant.depth = 15
    function invariant_silo_deposit() public {
        ISiloConfig.ConfigData memory collateral = siloConfig.getConfig(address(silo0));

        assertEq(
            token0.totalSupply(),
            silo0.getCollateralAssets() + silo0.getProtectedAssets()
            + token0.balanceOf(address(0xabc01)) + token0.balanceOf(address(0xabc02)) + token0.balanceOf(address(0xabc03)),
            "totalSupply"
        );

        assertEq(
            token0.balanceOf(address(silo0)), // this is only true if we do not transfer tokens directly
            silo0.getCollateralAssets() + silo0.getProtectedAssets(),
            "balanceOf"
        );

        assertEq(
            silo0.getCollateralAssets(),
            IShareToken(collateral.collateralShareToken).totalSupply(),
            "collateral shares == assets"
        );

        assertEq(
            silo0.getProtectedAssets(),
            IShareToken(collateral.protectedShareToken).totalSupply(),
            "protected shares == assets"
        );

        // silo 1

        assertEq(silo1.getCollateralAssets(), 0);
        assertEq(silo1.getProtectedAssets(), 0);
    }
}
