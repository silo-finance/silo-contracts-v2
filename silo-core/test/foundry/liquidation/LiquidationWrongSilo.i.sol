// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IInterestRateModel} from "silo-core/contracts/interfaces/IInterestRateModel.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {AssetTypes} from "silo-core/contracts/lib/AssetTypes.sol";

import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";
import {MintableToken} from "../_common/MintableToken.sol";

/*
FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc LiquidationWrongSiloTest
*/
contract LiquidationWrongSiloTest is SiloLittleHelper, Test {
    ISiloConfig public siloConfig;

    address public maliciousSilo = makeAddr("maliciousSilo");
    address public maliciousSiloConfig = makeAddr("maliciousSiloConfig");
    address public borrower = makeAddr("Borrower");

    function setUp() public {
        siloConfig = _setUpLocalFixture();
    }

    function testWrongSiloLiquidation() public {
        _createMaliciousSilo();

        vm.expectRevert(IPartialLiquidation.WrongSilo.selector);

        partialLiquidation.liquidationCall(
            maliciousSilo,
            address(token1),
            address(token1),
            borrower,
            0,
            false
        );
    }

    function _createMaliciousSilo() internal {
        bytes memory configData;
        vm.mockCall(maliciousSilo, configData, abi.encode(maliciousSiloConfig));
        vm.expectCall(maliciousSilo, configData);

        _maliciousAccrueInterestAndGetConfigs();
    }

    function _maliciousAccrueInterestAndGetConfigs() internal {
        bytes memory payload = abi.encodeWithSelector(
            ISiloConfig.accrueInterestAndGetConfigs.selector,
            maliciousSilo,
            borrower,
            Hook.LIQUIDATION
        );

        ISiloConfig.ConfigData memory collateralConfig;
        collateralConfig.silo = address(silo0);

        ISiloConfig.ConfigData memory debtConfig;
        debtConfig.silo = maliciousSilo;

        ISiloConfig.DebtInfo memory debtInfo;

        bytes memory returnData = abi.encode(collateralConfig, debtConfig, debtInfo);

        vm.mockCall(maliciousSiloConfig, payload, returnData);
        vm.expectCall(maliciousSiloConfig, payload);
    }
}
