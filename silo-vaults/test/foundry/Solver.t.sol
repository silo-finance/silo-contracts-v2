// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test, console2} from "forge-std/Test.sol";
import {SolverMock} from "./SolverMock.sol";

contract SolverTest is Test {
    SolverMock public solver;

    function setUp() public {
        solver = new SolverMock();
    }

    // IRM: https://etherscan.io/address/0x76074C0b66A480F7bc6AbDaA9643a7dc99e18314

    // rETH Silo: 0xB1590d554dC7d66F710369983b46a5905AD34c8c
    // borrow: 59231987692974885170
    // deposit: 180061059126299821361
    // uopt: 500000000000000000
    // ucrit: 900000000000000000

    // cbETH Silo: 0x2eaf84b425822edF450fC5FdeEc085f2e5aDa98b
    // borrow: 816978275918870307
    // deposit: 250393492534806137941
    // uopt: 800000000000000000
    // ucrit: 900000000000000000

    // wstETH Silo: 0x4f5717f1EfDec78a960f08871903B394e7Ea95Ed
    // borrow: 34074575863956002824
    // deposit: 181044948748268147908
    // uopt: 800000000000000000
    // ucrit: 900000000000000000

    // function testSolver() public {
    //     uint256[] memory borrow = new uint256[](3);
    //     borrow[0] = 59231987692974885170;
    //     borrow[1] = 816978275918870307;
    //     borrow[2] = 34074575863956002824;

    //     uint256[] memory deposit = new uint256[](3);
    //     deposit[0] = 180061059126299821361;
    //     deposit[1] = 250393492534806137941;
    //     deposit[2] = 181044948748268147908;

    //     uint256[] memory uopt = new uint256[](3);
    //     uopt[0] = 500000000000000000;
    //     uopt[1] = 800000000000000000;
    //     uopt[2] = 800000000000000000;

    //     uint256[] memory ucrit = new uint256[](3);
    //     ucrit[0] = 900000000000000000;
    //     ucrit[1] = 900000000000000000;
    //     ucrit[2] = 900000000000000000;

    //     uint256 amountToDistribute = 500 * 1e18; 

    //     uint256[] memory results = solver.callSolver(borrow, deposit, uopt, ucrit, amountToDistribute);

    //     // Verify total distributed matches input
    //     uint256 totalDistributed;
    //     for (uint i = 0; i < results.length; i++) {
    //         totalDistributed += results[i]; 
    //     }
    //     assertEq(totalDistributed, amountToDistribute);
    // }

    function testSolverWithFuzz(uint8 util1, uint8 util2, uint8 util3) public {
        vm.assume(util1 <= 100);
        vm.assume(util2 <= 100);
        vm.assume(util3 <= 100);     

        uint256[] memory deposit = new uint256[](3);
        deposit[0] = 180061059126299821361;
        deposit[1] = 250393492534806137941;
        deposit[2] = 181044948748268147908;

        uint256[] memory borrow = new uint256[](3);
        borrow[0] = deposit[0] * ( util1 + 1)  / 100 -1;
        borrow[1] = deposit[1] * ( util2 + 1) / 100;
        borrow[2] = deposit[2] * ( util3 + 1) / 100;

        uint256[] memory uopt = new uint256[](3);
        uopt[0] = 500000000000000000;
        uopt[1] = 800000000000000000;
        uopt[2] = 800000000000000000;

        uint256[] memory ucrit = new uint256[](3);
        ucrit[0] = 900000000000000000;
        ucrit[1] = 900000000000000000;
        ucrit[2] = 900000000000000000;

        uint256 amountToDistribute = 500 * 1e18; 

        uint256[] memory results = solver.callSolver(borrow, deposit, uopt, ucrit, amountToDistribute);

        // Verify total distributed matches input
        uint256 totalDistributed;
        for (uint i = 0; i < results.length; i++) {
            totalDistributed += results[i]; 
        }
        assertApproxEqAbs(totalDistributed, amountToDistribute, 10);

    }

}
