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

    /*
    FOUNDRY_PROFILE=echidna_leverage forge test --ffi --mt test_replay_flashloan_02 -vv
    */
    function test_replay_flashloan_02() public {
    LeverageTester.approve(383855509311575664067830998186522868026580228845865374397297937353222172540,0,0);
    LeverageTester.borrow(46743066108310,4,0);
    LeverageTester.siloLeverageDonation(6);
    LeverageTester.accrueInterestForSilo(1);
    LeverageTester.onFlashLoan(address(0x0),11798573263229900028877752088972703451660380960541695241631327209494509258020,778745504713184284183131820110091788224241812757807658563998399121741982798,"", RandomGenerator(10, 4, 26));
    LeverageTester.decreaseReceiveAllowance(485152531751332124132651321946671899670191609180820708281326203427778589017,7,2);
    LeverageTester.repayShares(1460478404485984578554781383703166034001974820165521674034671326596798517986,41,19);
    LeverageTester.assertBORROWING_HSPOST_F(5,39);
//    *wait* Time delay: 11463 seconds Block delay: 48489
    LeverageTester.flashLoan(0,21,0,0);
    LeverageTester.deposit(455,71,2,101);
    LeverageTester.repayShares(2281843857384916344741175783941243755585305668532744610093404238770313638525,9,9);
    LeverageTester.setReceiveApproval(11211882827732671065121382927546481179388343027582081300772263591240004287906,11,100);
    LeverageTester.setOraclePrice(12783030301923716341955457304376370239852960784907995288310807075825170785512,0);
    LeverageTester.siloLeverageImplementationDonation(9004576657907868877849063535727709679719341093550777075445626407618541566673);
    LeverageTester.siloLeverageImplementationDonation(897377803282519097666580043404064571445828404596995546066897920562152893);
    LeverageTester.siloLeverageImplementationDonation(193816155660884351240206559834388685405400497248409908138438960584228241754);
    LeverageTester.onFlashLoan(address(0x0),29046953800389942913680996997703903863747611160050342051027698736531973215171,73010143390315934406010559831118728393600729754696197287367516085911467577601,"", RandomGenerator(2, 29, 11));
    LeverageTester.transitionCollateral(1, RandomGenerator(162, 15, 254));
    LeverageTester.accrueInterestForBothSilos();
    LeverageTester.assert_LENDING_INVARIANT_B(35,1);
    LeverageTester.approve(0,2,0);
    LeverageTester.liquidationCall(43187699381666979426203365545589029210042042380021348594442300757465768392930,false, RandomGenerator(2, 0, 111));
    LeverageTester.withdraw(107774582421039924707360139971469563892107095982,21,23,26);
    LeverageTester.swapModuleDonation(658404155);
    LeverageTester.siloLeverageImplementationDonation(793606503293471314649648565603592767101023101843252493037316711281710667774);
    LeverageTester.switchCollateralToThisSilo(0);
    LeverageTester.siloLeverageImplementationDonation(6638933623280449588244161709373446511118782973482161122422307711748482319007);
    LeverageTester.receiveAllowance(323,3,0,2);
    LeverageTester.decreaseReceiveAllowance(40,27,10);
    LeverageTester.assertBORROWING_HSPOST_F(14,0);
    LeverageTester.accrueInterestForBothSilos();
    LeverageTester.assert_LENDING_INVARIANT_B(0,3);
    LeverageTester.openLeveragePosition(569582506324285037,1352076688, RandomGenerator(52, 23, 170));
    LeverageTester.assert_LENDING_INVARIANT_B(2,0);
    LeverageTester.transfer(7650406976543755,13,0);
    LeverageTester.decreaseReceiveAllowance(86803206570186216304294856119414167146625978547379240909188682553389546592,0,16);
    LeverageTester.assertBORROWING_HSPOST_F(0,1);
    LeverageTester.borrowSameAsset(2531442446,30,20);
//    *wait* Time delay: 209018 seconds Block delay: 265
    LeverageTester.setOraclePrice(16425445389049354229393669581452424168900983113287583935422339358493266377923,4);
    LeverageTester.receiveAllowance(416,29,32,16);
    LeverageTester.borrow(21409026068927963908990456348568942101657328499568907560845451521352134341940,4,5);
    LeverageTester.transferFrom(2819893111989681415674540622765926898099817003015122648439124056587973420515,0,32,3);
    LeverageTester.redeem(3733614622464763120196385530577958729546924703730249740173087335224663347952,143,85,157); // Time delay: 66543 seconds Block delay: 1847
    LeverageTester.transfer(1517868165349108405068964001821691339228721048946533499521660200741193246407,18,10);
    LeverageTester.swapModuleDonation(364804667479605703864037433607682946106476715096777270835948651625032970);
    LeverageTester.setReceiveApproval(3827264047175555923079876023155361189265330924687645324712746806455225649,24,36);
    LeverageTester.mint(7952528634674201222585288136418134684124459456673642656583317864549711444393,38,17,16);
    LeverageTester.approve(14989955175167124992552580785059774769452255544204520081770183862328268762343,12,50);
    LeverageTester.switchCollateralToThisSilo(1);
    LeverageTester.liquidationCall(853055756984073427370520565693270188344035935869851237410485903266993867516,false, RandomGenerator(196, 15, 71));
    LeverageTester.onFlashLoan(address(0x0),257594654614948621912909180167924610282697439,1,"", RandomGenerator(5, 7, 2));
    LeverageTester.siloLeverageDonation(15742951068358395070286736983644364376298461701684299302839268307083241089);
    LeverageTester.setReceiveApproval(83,4,2);
    LeverageTester.accrueInterestForSilo(0);
    LeverageTester.decreaseReceiveAllowance(438692564556992663814862939535668283065619921933745148766444433234897957139,0,0);
    LeverageTester.decreaseReceiveAllowance(1,3,1);
    LeverageTester.swapModuleDonation(6849872222925751053257499526560509424900141113921382306641892803620431176);
    LeverageTester.borrowShares(2604629194619880081720292933083074535492666254014474059994546203001839195321,9,122);
    LeverageTester.setReceiveApproval(3804736139241341061418443925568001548354536801668654359354663267837401705180,0,11);
    LeverageTester.liquidationCall(49,false, RandomGenerator(255, 18, 2));
    LeverageTester.openLeveragePosition(2733057956704177324,903903042833814667, RandomGenerator(27, 4, 76)); // Time delay: 60134 seconds Block delay: 46153
    LeverageTester.swapModuleDonation(4377930521592764289365755008267496274005086623288162789345877898110204390261);
    LeverageTester.setOraclePrice(198028809709884763950470097857898511674925220630491253953024584301022868626,6);
    LeverageTester.accrueInterest(0);
    LeverageTester.accrueInterestForSilo(1);
    LeverageTester.redeem(110,40,187,45);
    LeverageTester.accrueInterest(3);
    LeverageTester.increaseReceiveAllowance(0,0,0);
    LeverageTester.transferFrom(916478143107298882856941265841242659919279498991850482723578983150507090307,18,1,0);
    LeverageTester.repayShares(2956040045727820989069298603417552452543688312973741514259278965756257132356,0,16);
    LeverageTester.accrueInterest(4);
    LeverageTester.openLeveragePosition(7044741625024020353,6461, RandomGenerator(83, 84, 12));
    LeverageTester.increaseReceiveAllowance(0,0,1);
    LeverageTester.approve(3095191,0,24);
    LeverageTester.borrow(22,0,17);
    LeverageTester.assert_AllowanceDoesNotChangedForUserWhoOnlyApprove();
    LeverageTester.assertBORROWING_HSPOST_F(14,34);
    LeverageTester.borrowShares(187756256717546166317413736532063350215377126806748839799448019062824764096,0,22); // Time delay: 264638 seconds Block delay: 682
//    *wait* Time delay: 597 seconds Block delay: 398
    LeverageTester.accrueInterest(26);
    LeverageTester.increaseReceiveAllowance(0,7,2);
    LeverageTester.siloLeverageDonation(10636300203468232753797256991943472233767418656980723157245111022794848138);
    LeverageTester.assert_LENDING_INVARIANT_B(15,42);
    LeverageTester.assert_BORROWING_HSPOST_D(0,9);
    LeverageTester.approve(94597317,0,5);
    LeverageTester.onFlashLoan(address(0x0),4745265165155228303763098751318299576195266232262488567058627803900789010080,2,"", RandomGenerator(0, 9, 0));
    LeverageTester.assert_BORROWING_HSPOST_D(0,0);
    LeverageTester.redeem(15654223716390699973581947013136415591869540710213687556413670151245584936373,0,0,0);
    LeverageTester.transitionCollateral(285780171, RandomGenerator(14, 52, 9));
    LeverageTester.borrowSameAsset(13660448165267151352311826432697579780698127044166,3,133);
    LeverageTester.withdraw(422161545413551449647176518751025029022400456492097455755761630458419003214,3,2,0);
    LeverageTester.swapModuleDonation(611316046830613388372755138325861338092704834287776742500264106780287634492);
    LeverageTester.transitionCollateral(481306262547441284127990224565950200204037166577535379477000232102734181617, RandomGenerator(12, 8, 2));
    LeverageTester.redeem(220213650,2,56,9);
    LeverageTester.assertBORROWING_HSPOST_F(0,0);
    LeverageTester.switchCollateralToThisSilo(0);
    LeverageTester.transferFrom(0,0,0,0);
    LeverageTester.withdraw(91565950031753262315631309180241593184216757044895221947467279290843862004039,29,95,6);
    LeverageTester.decreaseReceiveAllowance(0,50,0);
    LeverageTester.receiveAllowance(3832573114131080551159502995069032076577907083407949262161461540382784398885,33,7,1);
    LeverageTester.decreaseReceiveAllowance(19850,2,0);
    LeverageTester.increaseReceiveAllowance(0,0,3);
    LeverageTester.borrowSameAsset(9570293798619915935243470503266812654830384855813,11,0);
    LeverageTester.siloLeverageDonation(12066864068538657020516764231427065033250106195457356170870338999458815374811);
    LeverageTester.repay(13312257738409333788632884633665280630141762410227184107349531494148573407914,17,106);
    LeverageTester.setLeverageFee(74994462404712870155618860335892013360055033704967931180341145044954171405);
    LeverageTester.transitionCollateral(91174090220893031456485462036836154691525632660612998431384776489313486103298, RandomGenerator(12, 6, 18));
    LeverageTester.mint(14335941673501115435771826710453335815944042441850793794780438212668856616,15,1,0);
    LeverageTester.repayShares(2,2,1);
    LeverageTester.assert_BORROWING_HSPOST_D(10,86);
    LeverageTester.assert_BORROWING_HSPOST_D(1,3);
    LeverageTester.deposit(0,53,0,64);
    LeverageTester.transitionCollateral(1260612672560790, RandomGenerator(41, 50, 0));
    LeverageTester.redeem(79349702237701343518184821337617507069019915989357132196624696675058509299497,75,103,23);
    LeverageTester.onFlashLoan(address(0x0),3372296725686510182312628724369361093554952179819640376767146831772705349514,7762036965439254528600945555560664484911358520451328635945334987587937298,"", RandomGenerator(135, 18, 21));
    LeverageTester.decreaseReceiveAllowance(0,1,44);
    LeverageTester.transferFrom(2,3,0,1);
    LeverageTester.liquidationCall(618587694442928327173166148635553121382868446515438196814312062597772422749,false, RandomGenerator(22, 0, 6));
    LeverageTester.accrueInterestForBothSilos();
    LeverageTester.setReceiveApproval(3776503250758434571015483126701020837983373734337604230877029217955966492479,18,5);
    LeverageTester.switchCollateralToThisSilo(0);
    LeverageTester.transitionCollateral(65722259680429473838674711260298938339767566831383021711634175746559596348340, RandomGenerator(64, 2, 145));
    LeverageTester.swapModuleDonation(665830036374702400571394595025246630725421848965807396780295033418596619513);
    LeverageTester.accrueInterestForSilo(2);
    LeverageTester.increaseReceiveAllowance(0,4,1);
    LeverageTester.onFlashLoan(address(0xdeadbeef),652594,27542853821350593499247093940772975366631295890107995045841996971274754119140,"", RandomGenerator(21, 0, 9));
    LeverageTester.approve(5605670745019009854996254262359064664840833976307827926530338826616474932,0,3);
    LeverageTester.assert_BORROWING_HSPOST_D(10,0);
    LeverageTester.decreaseReceiveAllowance(3757645258488044988523611954724376624926703147705169589040788293316554767736,47,4);
    LeverageTester.siloLeverageImplementationDonation(4184734442308956310662079612866642664451812665949307351985658641431808369);
    LeverageTester.transferFrom(1,21,13,17);
    LeverageTester.approve(1599459948333314332424307922704711807632383212977395060389358515821731503773,0,15);
    LeverageTester.repay(0,177,2);
    LeverageTester.receiveAllowance(587982663789127232665034093783663973318609665461837262159268646072588414850,0,1,86);
    LeverageTester.transfer(88948232030627805338238548011707255103827752568252345949772566386038959112594,14,0);
    LeverageTester.transitionCollateral(74571247804937884129773751436997370152353256583868077067299867076888962031, RandomGenerator(1, 68, 0));
    LeverageTester.deposit(2300119719349493148598948435560998031446063024439793573654260446877325849025,4,8,0);
    LeverageTester.setLeverageFee(4738602618635933516633981254554165634022556990619125971954806075967245850252); // Time delay: 79822 seconds Block delay: 24908
    LeverageTester.togglePauseRouter();
    LeverageTester.borrowShares(38248792,3,122);
    LeverageTester.deposit(0,0,0,0);
    LeverageTester.onFlashLoan(address(0x0),1698711223340515907410580565304619549725978228937393021523878500894030953961,26958460,"", RandomGenerator(6, 1, 4));
    LeverageTester.withdraw(16908050766896174066733407728485591270056435321581974755974876064939010436001,8,0,0);
    LeverageTester.borrowSameAsset(222222446759382326831276969251468128335230819600456198631267738235542325544,3,2);
    LeverageTester.flashLoan(3,4,66,8);
    }
}
