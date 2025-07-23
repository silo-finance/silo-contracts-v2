// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import {console2} from "forge-std/console2.sol";

import {Actor} from "silo-core/test/invariants/utils/Actor.sol";

// Contracts
import {LeverageTester} from "./LeverageTester.t.sol";
import {SetupLeverage} from "./SetupLeverage.t.sol";
import {InvariantsLeverage} from "./InvariantsLeverage.t.sol";

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
        LeverageTester.deposit(1,0,0,0);
        LeverageTester.openLeveragePosition(4506857007, 0, RandomGenerator(1, 0, 0));
    }

    /*
    FOUNDRY_PROFILE=echidna_leverage forge test -vv --ffi --mt test_EchidnaLeverage_onFlashLoan_0
    */
    function test_EchidnaLeverage_onFlashLoan_0() public {
        LeverageTester.onFlashLoan(
            address(0x0),
            144878998102916798939665310881083899372024861808743479,
            1068209701505743703662069164166715788602248289963999918073026641719,
            "",
            RandomGenerator(0, 0, 0)
        );
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

    // FOUNDRY_PROFILE=echidna_leverage forge test --ffi --mt test_replay_LENDING_HSPOST_D_transitionCollateral -vv
    function test_replay_LENDING_HSPOST_D_transitionCollateral() public {
        LeverageTester.mint(37377012585627349138416833614621264, 68, 8, 0);
        LeverageTester.assert_AllowanceDoesNotChangedForUserWhoOnlyApprove();
        LeverageTester.mint(91263930532508457067226357055013206427, 0, 43, 1);
        LeverageTester.approve(
            4693767025084829504728549001627725142013373768572652486144526826425602111, 0, 0
        );
        LeverageTester.assert_LENDING_INVARIANT_B(3, 77);
        LeverageTester.approve(20173546881046558932246292342151680399901847244410817409700673862154371, 0, 0);
        LeverageTester.repayShares(19761772054543692487490211516202293, 0, 0);
        LeverageTester.assert_LENDING_INVARIANT_B(0, 0);
        LeverageTester.transfer(1175745079946205372183956782191932569933290147407232973886925850268244772, 0, 0);
        LeverageTester.deposit(1220121080980483341180088841458962008721083028397603315405087406194053711, 0, 0, 0);
        LeverageTester.borrowSameAsset(1189295320661420378768046494214370, 0, 0);
        LeverageTester.setOraclePrice(1941492113288175123799033573114228796966266920469697365830438140109601, 0);
        LeverageTester.transfer(0, 0, 0);
        LeverageTester.repay(0, 0, 0);
        LeverageTester.mint(2, 0, 25, 1);
        LeverageTester.closeLeveragePosition(RandomGenerator(1, 0, 0));
        LeverageTester.borrowShares(106675216617470953612273915229355594252189242715585042259127104365034, 0, 0);
        LeverageTester.assertBORROWING_HSPOST_F(14, 1);
        LeverageTester.repay(367845465280968862049358840710100071837473236215553696354364305089055, 0, 0);
        LeverageTester.receiveAllowance(
            10042188267375893584101419355540308895267876422626915728310837304304726562, 0, 0, 0
        );
        LeverageTester.borrow(
            14889316231293521303000638444000568759909077363103434890889418256578668, 0, 0
        );
        LeverageTester.withdraw(
            70080046258413863271438511417722815567790071092488462672758693003983813176, 1, 0, 0
        );
        LeverageTester.liquidationCall(0, false, RandomGenerator(5, 2, 0));
        LeverageTester.repay(270376388814837912840698, 0, 0);
        LeverageTester.switchCollateralToThisSilo(0);
        LeverageTester.repay(
            259205741000817977977592448897897068162264841147220667615497787901496210, 0, 0
        );
        LeverageTester.borrowSameAsset(
            52829075790591245909921009569075756553518276768940526659247519093248397732, 0, 0
        );
        LeverageTester.accrueInterestForBothSilos();
        LeverageTester.transitionCollateral(754, RandomGenerator(21, 27, 77));
    }

    /*
    FOUNDRY_PROFILE=echidna_leverage forge test --ffi --mt test_replay_flashloan_01 -vv
    */
    function test_replay_flashloan_01() public {
        LeverageTester.setReceiveApproval(0,0,1);
        LeverageTester.accrueInterest(0);
        LeverageTester.closeLeveragePosition(RandomGenerator(1, 1, 0));
        LeverageTester.transfer(718054,0,0);
        LeverageTester.onFlashLoan(address(0x0),2,12780801841864762489723522957270760606708406331348606168316444720689193744020,"",RandomGenerator(16, 212, 40));
        LeverageTester.repay(8024500186558106128562437347906786904518362173633068064040652633161597469447,0,19);
        LeverageTester.assert_BORROWING_HSPOST_D(0,0);
        LeverageTester.mint(75736747354538440227190616304507821237,13,1,23);
        LeverageTester.accrueInterestForSilo(0);
        LeverageTester.accrueInterestForSilo(3);
        LeverageTester.increaseReceiveAllowance(105088421810884567,1,33);
        LeverageTester.liquidationCall(0,false,RandomGenerator(0, 0, 37));
        LeverageTester.borrowSameAsset(1742744256016363456767913478769768337543793568642598889285944847608618677778,3,0);
        LeverageTester.transitionCollateral(2381055509349605268845125936759200871347242184529868821691402614893202969300,RandomGenerator(255, 31, 1));
        LeverageTester.assertBORROWING_HSPOST_F(4,1);
        LeverageTester.assert_AllowanceDoesNotChangedForUserWhoOnlyApprove();
        LeverageTester.deposit(45173755392117345949045042321083115312743552376553437449210996565517287088,0,0,0);
        LeverageTester.setOraclePrice(48360200964784656631415371009019639834279281143781641666266516952684197472177,0);
        LeverageTester.swapModuleDonation(47991551630814282440778065006753839032104611867349543614064551732504137507);
        LeverageTester.closeLeveragePosition(RandomGenerator(78, 0, 1));
        LeverageTester.borrowSameAsset(22196782784891236813677017045494085861190931117288500014454764901592915559,9,1);
        LeverageTester.accrueInterest(0);
        LeverageTester.flashLoan(4,94,1,65);
        LeverageTester.setOraclePrice(5596950051894618896712163697522148227854298672411080983701202447615807155,5);
        LeverageTester.assertBORROWING_HSPOST_F(6,184);
        LeverageTester.assert_AllowanceDoesNotChangedForUserWhoOnlyApprove();
        LeverageTester.liquidationCall(992403169246541674751081885672463947169567387119634568711375684882669846641,false,RandomGenerator(5, 73, 79));
        LeverageTester.approve(437837496110236441133604804861222412920566703107631375348635456432958088754,33,0);
        LeverageTester.repayShares(11099955059503608572160550313984436549307537631858672177472501750063905090,4,13);
        LeverageTester.transferFrom(18,1,22,0);
        LeverageTester.assert_BORROWING_HSPOST_D(0,0);
        LeverageTester.mint(1132818721201107934417225517000587105625648136212319136125669561177092755499,0,0,0);
        LeverageTester.transitionCollateral(967940581952422505533982068120314345873082785408359511246312103718865537496,RandomGenerator(11, 3, 174));
        LeverageTester.deposit(3,5,0,36);
        LeverageTester.receiveAllowance(611814457774336451546889246771749797794320765348047553125370491206507415399,0,21,4);
        LeverageTester.setLeverageFee(12675697321674173);
        LeverageTester.siloLeverageImplementationDonation(109294361554498602078446860929924720933824686393895108824197747330324531543);
        LeverageTester.assert_PredictUserLeverageContractIsEqualToDeployed();
        LeverageTester.switchCollateralToThisSilo(0);
        LeverageTester.assert_UserLeverageContractInstancesAreUnique();
        LeverageTester.assert_BORROWING_HSPOST_D(4,1);
        LeverageTester.setOraclePrice(302640136460315843984877027532378656427346047427777809486030152107160224218,0);
        LeverageTester.transitionCollateral(2,RandomGenerator(6, 35, 0));
        LeverageTester.withdraw(13650553197721274359413836804265991604244647432443104894238468005013092971659,1,0,4);
        LeverageTester.flashLoan(365,368,1,65);
    }
}
