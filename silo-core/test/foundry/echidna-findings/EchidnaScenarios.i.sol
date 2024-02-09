// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Strings} from "openzeppelin-contracts/utils/Strings.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {MintableToken} from "../_common/MintableToken.sol";
import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";
import {SiloFixture, SiloConfigOverride} from "../_common/fixtures/SiloFixture.sol";

/*
    forge test -vv --ffi --mc EchidnaScenariosTest
*/
contract EchidnaScenariosTest is SiloLittleHelper, Test {
    uint256 constant ACTORS_COUNT = 3;
    mapping (uint256 index => address actor) actors;

    ISiloConfig siloConfig;

    constructor() {
        actors[0] = makeAddr("Index 0");
        actors[1] = makeAddr("Index 1");
        actors[2] = makeAddr("Index 2");
    }

    function setUp() public {
        siloConfig = _setUpLocalFixture("Echidna_MOCK");

        assertTrue(siloConfig.getConfig(address(silo0)).maxLtv != 0, "we need borrow to be allowed");

        token0.setOnDemand(true);
        token1.setOnDemand(true);

        // same block and time as for E2E Echidna
        vm.warp(1706745600);
        vm.roll(17336000);
    }

    /*
mint(uint8,bool,uint256): passing
maxBorrow_correctReturnValue(uint8): failed!💥
Call sequence:
depositNeverMintsZeroShares(0,false,39962600816669483677151)
depositNeverMintsZeroShares(161,true,22168924613129761549643809883710869859261573373213864899764932836300336298504)
borrow(2,false,39858486983777211695540)
*wait* Time delay: 1 seconds Block delay: 1
maxBorrow_correctReturnValue(0)

Event sequence:
Panic(1): Using assert
LogString(«Actor selected index:0») from: 0xa329c0648769a73afac7f9381e08fb43dbea72
LogString(«Max Assets to borrow:339682116») from: 0xa329c0648769a73afac7f9381e08fb43dbea72
Transfer(339682116) from: 0xbd748c717ca30862991dc44aaf0b4db9f8de12da
Transfer(339682116) from: 0xcd9a70c13c88863ece51b302a77d2eb98fbbbd65
Borrow(339682116, 339682116) from: 0x74551568ff6d425a2ec2fb2975e47afc7de96d70
error Revert AboveMaxLtv ()
error Revert AboveMaxLtv ()
error Revert AboveMaxLtv ()

    forge test -vv --ffi --mt test_cover_echidna_scenario_1
    */
    function test_cover_echidna_scenario_1() public {
        //        depositNeverMintsZeroShares(0,false,39962600816669483677151)
        vm.prank(_chooseActor(0));
        silo1.deposit(39962600816669483677151, _chooseActor(0));
        //        depositNeverMintsZeroShares(161,true,22168924613129761549643809883710869859261573373213864899764932836300336298504)
        vm.prank(_chooseActor(161));
        silo0.deposit(22168924613129761549643809883710869859261573373213864899764932836300336298504, _chooseActor(161));
        //        borrow(2,false,39858486983777211695540)
        vm.prank(_chooseActor(2));
        silo1.borrow(39858486983777211695540, _chooseActor(2), _chooseActor(2));
        //        *wait* Time delay: 1 seconds Block delay: 1
        vm.warp(block.timestamp + 1);
        //        maxBorrow_correctReturnValue(0)

        address actor = _chooseActor(0);
        uint256 maxAssets = silo0.maxBorrow(actor);

        (address protected, address collateral, ) = siloConfig.getShareTokens(address(silo1));
        emit log_named_decimal_uint("collateral shares", IShareToken(collateral).balanceOf(actor), 18);
        emit log_named_decimal_uint("maxAssets", maxAssets, 18);
        // assertEq(maxAssets, 339682116, "maxAssets from echidna simulation"); // TODO why echidna shows 339682116?

        vm.prank(actor);
        silo0.borrow(maxAssets, actor, actor); // should not revert!
    }

    function _chooseActor(
        uint256 value
    ) internal returns (address) {
        uint256 low = 0;
        uint256 high = ACTORS_COUNT - 1;

        if (value < low || value > high) {
            uint ans = low + (value % (high - low + 1));
            string memory valueStr = Strings.toString(value);
            string memory ansStr = Strings.toString(ans);
            bytes memory message = abi.encodePacked(
                "Clamping value ",
                valueStr,
                " to ",
                ansStr
            );
            emit log(string(message));
            return actors[ans];
        }

        return actors[value];
    }
}
