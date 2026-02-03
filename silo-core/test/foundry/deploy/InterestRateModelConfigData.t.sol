// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {console2} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";

import {InterestRateModelConfigData} from "../../../deploy/input-readers/InterestRateModelConfigData.sol";
import {IInterestRateModelV2} from "../../../contracts/interfaces/IInterestRateModelV2.sol";

contract InterestRateModelConfigDataTest is Test {
    InterestRateModelConfigData dataReader;

    function setUp() public {
        dataReader = new InterestRateModelConfigData();
    }

    /*

    {
    "name": "defaultAsset",
    "config": {
      "uopt": 10,
      "ucrit": 8,
      "ulow": 9,
      "ki": 4,
      "kcrit": 3,
      "klow": 5,
      "klin": 6,
      "beta": 2,
      "ri": 7,
      "Tcrit": 1
    }

    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_irmReader_testConfig -vv
    */
    function test_irmReader_testConfig() public {
        IInterestRateModelV2.Config memory cfg = dataReader.getConfigData("testConfig");

        console2.log("cfg.uopt", cfg.uopt);
        console2.log("cfg.ucrit", cfg.ucrit);
        console2.log("cfg.ulow", cfg.ulow);
        console2.log("cfg.ki", cfg.ki);
        console2.log("cfg.kcrit", cfg.kcrit);
        console2.log("cfg.klow", cfg.klow);
        console2.log("cfg.klin", cfg.klin);
        console2.log("cfg.beta", cfg.beta);
        console2.log("cfg.ri", cfg.ri);
        console2.log("cfg.Tcrit", cfg.Tcrit);

        assertEq(cfg.Tcrit, 1, "Tcrit");
        assertEq(cfg.beta, 2, "beta");
        assertEq(cfg.kcrit, 3, "kcrit");
        assertEq(cfg.ki, 4, "ki");
        assertEq(cfg.klow, 5, "klow");
        assertEq(cfg.klin, 6, "klin");
        assertEq(cfg.ri, 7, "ri");
        assertEq(cfg.ucrit, 8, "ucrit");
        assertEq(cfg.ulow, 9, "ulow");
        assertEq(cfg.uopt, 10, "uopt");
    }

    /*
    for bridgeETHv15
    */
    function test_irmReader_bridgeETHv15() public {
        IInterestRateModelV2.Config memory cfg = dataReader.getConfigData("bridgeETHv15");

        console2.log("cfg.uopt", cfg.uopt);
        console2.log("cfg.ucrit", cfg.ucrit);
        console2.log("cfg.ulow", cfg.ulow);
        console2.log("cfg.ki", cfg.ki);
        console2.log("cfg.kcrit", cfg.kcrit);
        console2.log("cfg.klow", cfg.klow);
        console2.log("cfg.klin", cfg.klin);
        console2.log("cfg.beta", cfg.beta);
        console2.log("cfg.ri", cfg.ri);
        console2.log("cfg.Tcrit", cfg.Tcrit);

        assertEq(cfg.uopt, 900000000000000001, "uopt");
        assertEq(cfg.ucrit, 900000000000000002, "ucrit");
        assertEq(cfg.ulow, 900000000000000000, "ulow");
        assertEq(cfg.ki, 0, "ki");
        assertEq(cfg.kcrit, 7927447996, "kcrit");
        assertEq(cfg.klow, 1937820621, "klow");
        assertEq(cfg.klin, 0, "klin");
        assertEq(cfg.beta, 11574074074074, "beta");
        assertEq(cfg.ri, 1744038559, "ri");
        assertEq(cfg.Tcrit, 0, "Tcrit");
    }
}