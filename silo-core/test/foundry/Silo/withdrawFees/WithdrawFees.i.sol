// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";
import {SiloConfigOverride} from "../../_common/fixtures/SiloFixture.sol";
import {SiloFixtureWithVeSilo as SiloFixture} from "../../_common/fixtures/SiloFixtureWithVeSilo.sol";

/*
    forge test -vv --ffi --mc WithdrawFeesIntegrationTest
*/
contract WithdrawFeesIntegrationTest is SiloLittleHelper, Test {

    address user = makeAddr("user");
    address borrower = makeAddr("borrower");

    function _setUp(uint8 _decimals0, uint8 _decimals1) public {
        SiloFixture siloFixture = new SiloFixture();

        SiloConfigOverride memory configOverride;

        token0 = new MintableToken(_decimals0);
        token1 = new MintableToken(_decimals1);

        token0.setOnDemand(true);
        token1.setOnDemand(true);

        configOverride.token0 = address(token0);
        configOverride.token1 = address(token1);

        (, silo0, silo1,,,) = siloFixture.deploy_local(configOverride);
    }

    /*
    forge test -vv --ffi --mt test_fee_oneToken
    */
    function test_fee_oneToken(
//        uint8 _decimals
    ) public {
        uint8 _decimals = 18;

        vm.assume(_decimals <= 18);
        vm.assume(_decimals > 0);

        _setUp(_decimals, _decimals);

        uint256 one0 = 10 ** _decimals;
        uint256 one1 = 10 ** _decimals;

        _depositForBorrow(one1, user);
        _deposit(one0, borrower);
        _borrow(_fragmentedAmount(one1 / 2, _decimals - 1), borrower);

        vm.warp(block.timestamp + 1);
        uint256 interest = silo1.accrueInterest();

        (uint160 daoAndDeployerRevenue,, uint64 interestFraction,,,) = silo1.getSiloStorage();
        emit log_named_uint("interest", interest);
        emit log_named_uint("interestFraction", interestFraction);
        emit log_named_uint("daoAndDeployerRevenue", daoAndDeployerRevenue);

        assertEq(interest, 1159717550, "interest");
        assertGt(interestFraction, 0, "expect non zero interestFraction");

        uint256 expectedTotalFees = 277460680 * 1e18;

        assertGt(daoAndDeployerRevenue, 0, "expect any fee");
        assertGt(daoAndDeployerRevenue, expectedTotalFees, "expect fee");

        // "daoFee": 1500, "deployerFee": 1000,
        uint256 daoFees = daoAndDeployerRevenue * 15 / 25 / 1e18;
        uint256 deployerFees = daoAndDeployerRevenue * 10 / 25 / 1e18;
        emit log_named_uint("calculated daoFees", daoFees);
        emit log_named_uint("calculated deployerFees", deployerFees);

        vm.expectEmit(address(silo1));
        emit ISilo.WithdrawnFeed(daoFees, deployerFees);
        silo1.withdrawFees();
    }

    function _fragmentedAmount(uint256 _amount, uint8 _decimals) internal pure returns (uint256) {
        for (uint i; i < _decimals; i++) {
            _amount +=  10 ** i;
        }

        return _amount;
    }
}
