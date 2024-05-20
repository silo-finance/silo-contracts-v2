// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {SiloConfig, ISiloConfig} from "silo-core/contracts/SiloConfig.sol";
import {ILeverageBorrower} from "silo-core/contracts/interfaces/ILeverageBorrower.sol";

import {SiloLeverageNonReentrant} from "../../_mocks/SiloLeverageNonReentrant.sol";

/**
FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc LeverageBorrowReentrancy
 */
contract LeverageBorrowReentrancy is Test {
    SiloLeverageNonReentrant internal _silo;
    SiloConfig internal _siloConfig;

    function setUp() public {
        _silo = new SiloLeverageNonReentrant(ISiloFactory(address(0)));

        ISiloConfig.ConfigData memory _configData0;
        _configData0.silo = address(_silo);
        _configData0.token = makeAddr("token0");
        _configData0.debtShareToken = makeAddr("debtShareToken0");

        ISiloConfig.ConfigData memory _configData1;
        _configData1.silo = makeAddr("silo1");
        _configData1.token = makeAddr("token1");
        _configData1.debtShareToken = makeAddr("debtShareToken1");

        _siloConfig = new SiloConfig(1, _configData0, _configData1);

        _silo.forceConfigSetup(_siloConfig);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vv --ffi --mt test_LeverageReentrancyCall
    */
    function test_LeverageReentrancyCall() public {
        bytes memory data;

        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        // Inputs don't matter. We only need to activate/verify reentrancy protection.
        _silo.leverage(
            0, // _assets
            ILeverageBorrower(address(0)), // _receiver
            address(0), // _borrower
            false, // sameAsset
            data // _data
        );
    }
}
