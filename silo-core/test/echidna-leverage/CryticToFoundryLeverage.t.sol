// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import {console2} from "forge-std/console2.sol";

import {Actor} from "silo-core/test/invariants/utils/Actor.sol";

// Contracts
import {LeverageTester} from "./LeverageTester.t.sol";
import {SetupLeverage} from "./SetupLeverage.t.sol";
import {InvariantsLeverage} from "./InvariantsLeverage.t.sol";
import {LeverageHandler} from "./handlers/user/LeverageHandler.t.sol";

/*
 * Test suite that converts from  "fuzz tests" to foundry "unit tests"
 * The objective is to go from random values to hardcoded values that can be analyzed more easily
 */
contract CryticToFoundryLeverage is InvariantsLeverage, SetupLeverage {
    uint256 constant DEFAULT_TIMESTAMP = 337812;

    CryticToFoundryLeverage LeverageTester = this;

    function setUp() public {
        // Deploy protocol contracts
        _setUp();

        // Deploy actors
        _setUpActors();

        // Initialize handler contracts
        _setUpHandlers();

        vm.warp(DEFAULT_TIMESTAMP);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 FAILING INVARIANTS REPLAY                                 //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                              FAILING POSTCONDITIONS REPLAY                                //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /*
    FOUNDRY_PROFILE=echidna_leverage forge test -vv --ffi --mt test_EchidnaLeverage_leverage
    */
    function test_EchidnaLeverage_leverage() public {
        LeverageTester.deposit(3108972722022, 0, 1, 1);
        LeverageTester.openLeveragePosition(100000000000000001, 23, RandomGenerator(25, 0, 10));
    }

    /*
    FOUNDRY_PROFILE=echidna_leverage forge test -vv --ffi --mt test_EchidnaLeverage_onFlashLoan_0
    */
    function test_EchidnaLeverage_onFlashLoan_0() public {
        LeverageTester.onFlashLoan(address(0x0),144878998102916798939665310881083899372024861808743479,1068209701505743703662069164166715788602248289963999918073026641719,"",RandomGenerator(0, 0, 0));
    }

    /*
    FOUNDRY_PROFILE=echidna_leverage forge test -vv --ffi --mt test_EchidnaLeverage_flashLoan
    */
    function test_EchidnaLeverage_flashLoan() public {
        LeverageTester.transitionCollateral(0, RandomGenerator(48, 36, 4));
        LeverageTester.decreaseReceiveAllowance(
            2506243515399456898424707917941860539866995294705255171183520068680138867843, 0, 0
        );
        LeverageTester.setReceiveApproval(
            1913155963736077783573909335365462004495178792799802300617066144401103308184, 12, 0
        );
        LeverageTester.repay(3, 0, 0);
        LeverageTester.borrowShares(52552148424743107896246849922638425203440549452885117072281613847158652922, 2, 0);
        LeverageTester.deposit(196855952236441851091097133843931679592906339684308647519235638159288287410, 4, 2, 0);
        LeverageTester.borrow(69688993027737938760066380191416843761588828233301338767889364150720458885, 0, 0);
        LeverageTester.redeem(0, 0, 0, 0);
        LeverageTester.setOraclePrice(426921937436419841960201811563973385142725697675286209481810704706580139174, 0);
        LeverageTester.assert_AllowanceDoesNotChangedForUserWhoOnlyApprove();
        LeverageTester.deposit(22137860343374382075721782021272395636457263467127151986574824467746356, 27, 1, 2);
        LeverageTester.redeem(833585, 0, 0, 0);
        LeverageTester.assert_BORROWING_HSPOST_D(0, 2);
        LeverageTester.decreaseReceiveAllowance(0, 0, 0);
        LeverageTester.withdraw(12693733382182432, 0, 2, 0);
        LeverageTester.switchCollateralToThisSilo(0);
        LeverageTester.borrowShares(0, 0, 0);
        LeverageTester.mint(4913404982049912781778392828502524653, 0, 0, 1);
        LeverageTester.approve(2490680190444051908068858410834769730383782160266394512521265613143301399, 0, 3);
        LeverageTester.borrowShares(1, 3, 10);
        LeverageTester.increaseReceiveAllowance(
            391973769657740080218754868106253814031280916767763404176632560007462046, 0, 0
        );
        LeverageTester.withdraw(47741001772244072228901434743683277966383713336494840533962016659426024580, 4, 0, 1);
        LeverageTester.transfer(28262775532425357991198708953464329363003675068910285841088531499587314696470, 1, 0);
        LeverageTester.setReceiveApproval(
            507606517474450132998241132371234214242899071084181319930082545356247059019, 7, 0
        );
        LeverageTester.redeem(238061893215429977396790843149374670765627237310851972970105228488461581470, 0, 1, 2);
        LeverageTester.setReceiveApproval(
            345957942891661522125228166440086685362746088020517059088196480270243574166, 0, 1
        );
        LeverageTester.accrueInterest(0);
        LeverageTester.assert_LENDING_INVARIANT_B(0, 16);
        LeverageTester.setReceiveApproval(
            311816311965755670072047901472851117588109351016112447432727435262343563314, 0, 0
        );
        LeverageTester.setReceiveApproval(281346305033155, 0, 0);
        LeverageTester.transferFrom(
            937338916035923317064455539115924757115701221115794661484537172102261420625, 0, 0, 0
        );
        LeverageTester.borrow(73832326517727344900667465947443499688346842152951680879269498345349493037, 6, 0);
        LeverageTester.setReceiveApproval(819195, 0, 0);
        LeverageTester.approve(10443591337282622506808132517973728624315659746381135595136035003027, 4, 0);
        LeverageTester.openLeveragePosition(8046, 2621044031551101281, RandomGenerator(0, 81, 7));
        LeverageTester.assertBORROWING_HSPOST_F(0, 0);
        LeverageTester.assertBORROWING_HSPOST_F(0, 0);
        LeverageTester.repay(650070740855108722367042977680183968331904141531680897714969681577169332363, 0, 0);
        LeverageTester.setReceiveApproval(
            667276612231248455026895208616260496401399660543591216149552513214484200150, 0, 5
        );
        LeverageTester.setReceiveApproval(
            32859921402820668639879032312298514147236519854447112694477502761382976753453, 92, 2
        );
        LeverageTester.withdraw(11467826885324650587615577054266990387406515429063755400231433304373291151, 0, 0, 0);
        LeverageTester.transitionCollateral(495355600, RandomGenerator(3, 1, 8));
        LeverageTester.withdraw(862854139352012412875475274642512604648994646030876322784722344502907675275, 0, 0, 0);
        LeverageTester.flashLoan(5, 5009720867736221820684179033623054645222156937915086752668694570371969429445, 8, 0);
        LeverageTester.flashLoan(
            1, 9300860518432582072233127002492206515438141778154890838101482432814708311882, 4, 18
        );
    }
}
