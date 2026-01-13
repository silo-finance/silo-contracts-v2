// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloFactory} from "silo-core/contracts/SiloFactory.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {Silo} from "silo-core/contracts/Silo.sol";
import {ShareProtectedCollateralToken} from "silo-core/contracts/utils/ShareProtectedCollateralToken.sol";
import {ShareDebtToken} from "silo-core/contracts/utils/ShareDebtToken.sol";
import {SiloConfig} from "silo-core/contracts/SiloConfig.sol";
import {SiloFactory} from "silo-core/contracts/SiloFactory.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";

contract SiloFactoryMock is SiloFactory {
    address public constant SILO0 = address(0x1111111111111111111111111111111111111111);
    address public constant SILO1 = address(0x2222222222222222222222222222222222222222);

    constructor(address _daoFeeReceiver) SiloFactory(_daoFeeReceiver) {}

    // removing all validation will allow us to test events in easy way
    function _createValidateSilosAndShareTokens(
        ISiloConfig, /*_siloConfig*/
        address, /*_siloImpl*/
        address, /*_shareProtectedCollateralTokenImpl*/
        address, /*_shareDebtTokenImpl*/
        address /*_creator*/
    ) internal virtual override returns (ISilo silo0, ISilo silo1) {
        return (ISilo(SILO0), ISilo(SILO1));
    }
}

/*
FOUNDRY_PROFILE=core_test forge test -vv --ffi --mc SiloFactoryEventTest
*/
contract SiloFactoryEventTest is Test {
    function setUp() public {
        // siloConfig = _setUpLocalFixture();
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_siloFactory_events
    */
    function test_siloFactory_events() public {
        SiloFactoryMock factoryMock = new SiloFactoryMock(makeAddr("daoFeeReceiver"));
        ISiloConfig siloConfig = ISiloConfig(makeAddr("siloConfig"));
        address hookReceiver = makeAddr("hookReceiver");

        uint24 protectedTokenType = uint24(Hook.PROTECTED_TOKEN);
        uint24 debtTokenType = uint24(Hook.DEBT_TOKEN);

        address silo0 = factoryMock.SILO0();
        address silo1 = factoryMock.SILO1();

        address asset0 = makeAddr("asset0");
        address asset1 = makeAddr("asset1");

        address protectedShareToken0 = makeAddr("protectedShareToken0");
        address debtShareToken0 = makeAddr("debtShareToken0");
        address protectedShareToken1 = makeAddr("protectedShareToken1");
        address debtShareToken1 = makeAddr("debtShareToken1");

        vm.mockCall(silo0, abi.encodeWithSelector(ISilo.initialize.selector, address(siloConfig)), abi.encode(true));
        vm.mockCall(
            protectedShareToken0,
            abi.encodeWithSelector(ISilo.initialize.selector, silo0, hookReceiver, protectedTokenType),
            abi.encode(true)
        );
        vm.mockCall(
            debtShareToken0,
            abi.encodeWithSelector(ISilo.initialize.selector, silo0, hookReceiver, debtTokenType),
            abi.encode(true)
        );
        vm.mockCall(silo0, abi.encodeWithSelector(IShareToken.hookReceiver.selector), abi.encode(hookReceiver));
        vm.mockCall(silo0, abi.encodeWithSelector(ISilo.updateHooks.selector), abi.encode(true));
        vm.mockCall(silo0, abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(asset0));

        vm.mockCall(silo1, abi.encodeWithSelector(ISilo.initialize.selector, address(siloConfig)), abi.encode(true));
        vm.mockCall(
            protectedShareToken1,
            abi.encodeWithSelector(ISilo.initialize.selector, silo1, hookReceiver, protectedTokenType),
            abi.encode(true)
        );
        vm.mockCall(
            debtShareToken1,
            abi.encodeWithSelector(ISilo.initialize.selector, silo1, hookReceiver, debtTokenType),
            abi.encode(true)
        );
        vm.mockCall(silo1, abi.encodeWithSelector(IShareToken.hookReceiver.selector), abi.encode(hookReceiver));
        vm.mockCall(silo1, abi.encodeWithSelector(ISilo.updateHooks.selector), abi.encode(true));
        vm.mockCall(silo1, abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(asset1));

        vm.mockCall(
            address(siloConfig),
            abi.encodeWithSelector(ISiloConfig.getShareTokens.selector, silo0),
            abi.encode(protectedShareToken0, silo0, debtShareToken0)
        );
        vm.mockCall(
            address(siloConfig),
            abi.encodeWithSelector(ISiloConfig.getShareTokens.selector, silo1),
            abi.encode(protectedShareToken1, silo1, debtShareToken1)
        );

        vm.expectEmit(true, true, true, true);
        emit ISiloFactory.NewSiloShareTokens(protectedShareToken0, silo0, debtShareToken0);
        vm.expectEmit(true, true, true, true);
        emit ISiloFactory.NewSiloShareTokens(protectedShareToken1, silo1, debtShareToken1);

        vm.expectEmit(true, true, true, true);
        emit ISiloFactory.NewSiloHook(silo0, hookReceiver);
        vm.expectEmit(true, true, true, true);
        emit ISiloFactory.NewSiloHook(silo1, hookReceiver);

        factoryMock.createSilo({
            _siloConfig: ISiloConfig(makeAddr("siloConfig")),
            _siloImpl: address(new Silo(factoryMock)),
            _shareProtectedCollateralTokenImpl: address(new ShareProtectedCollateralToken()),
            _shareDebtTokenImpl: address(new ShareDebtToken()),
            _deployer: address(0),
            _creator: address(this)
        });
    }
}
