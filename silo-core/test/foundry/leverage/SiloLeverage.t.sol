// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IZeroExSwapModule} from "silo-core/contracts/interfaces/IZeroExSwapModule.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {SiloLeverage, ISiloLeverage} from "silo-core/contracts/leverage/SiloLeverage.sol";

import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    FOUNDRY_PROFILE=core_test  forge test -vv --ffi --mc SiloLeverageTest
*/
contract SiloLeverageTest is SiloLittleHelper, Test {
    using SiloLensLib for ISilo;
    using ShareTokenDecimalsPowLib for uint256;

    ISiloConfig siloConfig;

    function setUp() public {
        siloConfig = _setUpLocalFixture();

        assertTrue(siloConfig.getConfig(address(silo0)).maxLtv != 0, "we need borrow to be allowed");
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_leverage_happyPath
    */
    function test_leverage_happyPath() public {
        token0.setOnDemand(true);
        token1.setOnDemand(true);

        address user = makeAddr("user");

        SiloLeverage siloLeverage = new SiloLeverage(address(this));

        ISiloLeverage.FlashArgs memory flashArgs = ISiloLeverage.FlashArgs({
            amount: 1e18,
            token: silo1.asset(),
            flashDebtLender: address(silo1)
        });

        IZeroExSwapModule.SwapArgs memory swapArgs = IZeroExSwapModule.SwapArgs({
            buyToken: address(silo0.asset()),
            sellToken: address(silo1.asset()),
            allowanceTarget: address(1),
            exchangeProxy: address(2),
            swapCallData: ""
        });

        ISiloLeverage.DepositArgs memory depositArgs = ISiloLeverage.DepositArgs({
            amount: 0.1e18,
            receiver: user,
            collateralType: ISilo.CollateralType.Collateral,
            silo: silo0
        });

        ISilo borrowSilo = silo1;

        siloLeverage.leverage(flashArgs, swapArgs, depositArgs, borrowSilo);
    }
}
