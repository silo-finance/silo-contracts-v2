// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {Strings} from "openzeppelin5/utils/Strings.sol";
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
    uint256 constant INTEREST_TO_COMPARE = 10332;
    uint256 constant INTEREST_TIME = 1 days;

    address user = makeAddr("user");
    address borrower = makeAddr("borrower");

    function _setUp(uint256 _amount, uint8 _decimals) public {
        SiloFixture siloFixture = new SiloFixture();

        SiloConfigOverride memory configOverride;

        token0 = new MintableToken(_decimals);
        token1 = new MintableToken(_decimals);

        token0.setOnDemand(true);
        token1.setOnDemand(true);

        configOverride.token0 = address(token0);
        configOverride.token1 = address(token1);

        (, silo0, silo1,,,) = siloFixture.deploy_local(configOverride);

        uint256 one = 10 ** _decimals;

        _depositForBorrow(_amount * one, user);
        _deposit(_amount * one, borrower);
        _borrow(_fragmentedAmount(_amount * one / 2, _decimals - 1), borrower);
    }

    /*
    forge test -vv --ffi --mt test_fee_oneToken_18
    */
    function test_fee_oneToken_18() public {
        uint8 _decimals = 18;

        _setUp(1, _decimals);

        vm.warp(block.timestamp + 1);
        uint256 interest = silo1.accrueInterest();

        (uint192 daoAndDeployerRevenue,,,,) = silo1.getSiloStorage();
        ISilo.Fractions memory fractions = silo1.getFractionsStorage();

        emit log_named_uint("interest", interest);
        emit log_named_uint("fractions.interest", fractions.interest);
        emit log_named_uint("fractions.revenue", fractions.revenue);
        emit log_named_uint("daoAndDeployerRevenue", daoAndDeployerRevenue);

        assertEq(interest, 1159717550, "interest");
        assertEq(fractions.interest, 0, "expect NO fractions because of threshold");

        assertEq(fractions.revenue, 0, "expect NO fractions because of threshold");
        assertEq(daoAndDeployerRevenue, 289929387, "expect daoAndDeployerRevenue");

        vm.expectEmit(address(silo1));
        uint256 daoFees = 173957632;
        uint256 deployerFees = 115971755;
        emit ISilo.WithdrawnFees(daoFees, deployerFees, false);
        silo1.withdrawFees();
    }

    /*
    forge test -vv --ffi --mt test_fee_oneToken_8
    */
    function test_fee_oneToken_8() public {
        uint8 _decimals = 8;

        // we have 8 decimals, so with higher amount, we should get similar results as for 18
        // they wil not match 100% because we crating fragmented borrow amount
        _setUp(1, _decimals);

        vm.warp(block.timestamp + 1);
        uint256 interest = silo1.accrueInterest();

        (uint192 daoAndDeployerRevenue,,,,) = silo1.getSiloStorage();
        ISilo.Fractions memory fractions = silo1.getFractionsStorage();

        emit log_named_uint("interest", interest);
        emit log_named_uint("fractions.interest", fractions.interest);
        emit log_named_uint("fractions.revenue", fractions.revenue);
        emit log_named_uint("daoAndDeployerRevenue", daoAndDeployerRevenue);

        assertEq(interest, 1109842720, "interest");
        assertEq(fractions.interest, 502466316910034951, "expect fractions.interest");

        assertEq(fractions.revenue, 0, "expect fractions.revenue");
        assertEq(daoAndDeployerRevenue, 277460680, "expect daoAndDeployerRevenue");

        vm.expectEmit(address(silo1));
        uint256 daoFees = 166476408;
        uint256 deployerFees = 110984272;
        emit ISilo.WithdrawnFees(daoFees, deployerFees, false);
        silo1.withdrawFees();
    }

    /*
    forge test -vv --ffi --mt test_fee_oneToken_6
    */
    function test_fee_oneToken_6() public {
        uint8 _decimals = 6;

        _setUp(1, _decimals);

        uint192 prevDaoAndDeployerRevenue;
        uint256 prevInterest;
        uint64 prevInterestFraction;
        uint64 prevRevenueFraction;
        uint256 interest;

        for (uint t = 1; t < 24 hours; t++) {
            vm.warp(block.timestamp + 1);
            interest = silo1.accrueInterest();

            if (interest != 0) {
                emit log_named_uint("we got interest after s", t);
                emit log_named_uint("interest", interest);
                break;
            }

            (uint192 daoAndDeployerRevenue,,,,) = silo1.getSiloStorage();

            ISilo.Fractions memory fractions = silo1.getFractionsStorage();

            emit log_named_uint(string.concat("#", Strings.toString(t), " interest"), interest);
            emit log_named_uint(string.concat("#", Strings.toString(t), " fractions.interest"), fractions.interest);
            emit log_named_uint(string.concat("#", Strings.toString(t), " fractions.revenue"), fractions.revenue);
            emit log_named_uint(string.concat("#", Strings.toString(t), " daoAndDeployerRevenue"), daoAndDeployerRevenue);

            assertEq(
                interest,
                0,
                string.concat("#", Strings.toString(t), " interest zero, decimals too small to generate it")
            );

            assertEq(
                daoAndDeployerRevenue,
                prevDaoAndDeployerRevenue,
                string.concat("#", Strings.toString(t), " revenue stay zero until we got interest")
            );

            assertGt(
                fractions.interest,
                prevInterestFraction,
                string.concat("#", Strings.toString(t), "prevInterestFraction incrementing")
            );

            if (prevInterest == interest) {
                assertEq(
                    fractions.revenue,
                    prevRevenueFraction,
                    string.concat(
                        "#", Strings.toString(t), "revenueFraction not changed, because interest did not increased"
                    )
                );
            } else {
                assertGt(
                    daoAndDeployerRevenue * 1e18 + fractions.revenue,
                    prevDaoAndDeployerRevenue * 1e18 + prevRevenueFraction,
                    string.concat("#", Strings.toString(t), "Revenue incrementing")
                );
            }

            prevDaoAndDeployerRevenue = daoAndDeployerRevenue;
            prevInterest = interest;
            prevInterestFraction = fractions.interest;
            prevRevenueFraction = fractions.revenue;

            vm.expectRevert();
            silo1.withdrawFees();
        }

        assertGt(interest, 0, "expect some interest at this point");

        (uint192 daoAndDeployerRevenue,,,,) = silo1.getSiloStorage();
        ISilo.Fractions memory fractions = silo1.getFractionsStorage();

        emit log_named_uint("#final interest", interest);
        emit log_named_uint("#final fractions.interest", fractions.interest);
        emit log_named_uint("#final fractions.revenue", fractions.revenue);
        emit log_named_uint("#final daoAndDeployerRevenue", daoAndDeployerRevenue);

        assertLt(
            fractions.interest,
            prevInterestFraction,
            "prevInterestFraction is result of modulo, so once we got interest it should circle-drop"
        );

        vm.warp(block.timestamp + 60);

        silo1.accrueInterest();

        (prevDaoAndDeployerRevenue,,,,) = silo1.getSiloStorage();

        vm.expectEmit(address(silo1));
        emit ISilo.WithdrawnFees(1, 1, false);

        silo1.withdrawFees();

        assertGe(
            prevDaoAndDeployerRevenue,
            2,
            "expect revenue to be at lest 2 wei, because it has to be split by 2 to be ready to withdraw"
        );

        emit log_named_decimal_uint("# daoAndDeployerRevenue", prevDaoAndDeployerRevenue, 18);

        (daoAndDeployerRevenue,,,,) = silo1.getSiloStorage();
        assertLt(daoAndDeployerRevenue, 10 ** _decimals, "[daoAndDeployerRevenue] only fraction left < 1e18");
    }

    /*
    forge test -vv --ffi --mt test_fee_compare_days
    */
    function test_fee_compare_days() public {
        uint8 _decimals = 6;

        _setUp(1, _decimals);

        vm.warp(block.timestamp + INTEREST_TIME);

        uint256 interest = silo1.accrueInterest();

        assertEq(interest, INTEREST_TO_COMPARE, "compare: days at once");
    }

    /*
    forge test -vv --ffi --mt test_fee_compare_second
    */
    function test_fee_compare_second() public {
        uint8 _decimals = 6;

        _setUp(1, _decimals);

        uint256 sum;

        for (uint256 i; i < INTEREST_TIME; i++) {
            vm.warp(block.timestamp + 1);
            sum += silo1.accrueInterest();
        }

        assertEq(sum, INTEREST_TO_COMPARE, "compare: per second, it should be equal");
    }

    function _fragmentedAmount(uint256 _amount, uint8 _decimals) internal pure returns (uint256) {
        for (uint i; i < _decimals; i++) {
            _amount +=  10 ** i;
        }

        return _amount;
    }
}
