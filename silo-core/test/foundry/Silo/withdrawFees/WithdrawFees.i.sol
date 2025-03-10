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

        _depositForBorrow(_amount* one, user);
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

        (uint160 daoAndDeployerRevenue,, uint64 interestFraction,,,) = silo1.getSiloStorage();
        emit log_named_uint("interest", interest);
        emit log_named_uint("interestFraction", interestFraction);
        emit log_named_uint("daoAndDeployerRevenue", daoAndDeployerRevenue);

        assertEq(interest, 1159717550, "interest");
        assertEq(interestFraction, 599999999747887489, "expect interestFraction");

        assertEq(daoAndDeployerRevenue, 289929387_500000000000000000, "expect daoAndDeployerRevenue");

        vm.expectEmit(address(silo1));
        uint256 daoFees = 173957632;
        uint256 deployerFees = 115971755;
        emit ISilo.WithdrawnFeed(daoFees, deployerFees);
        silo1.withdrawFees();
    }

    /*
    forge test -vv --ffi --mt test_fee_oneToken_8
    */
    function test_fee_oneToken_8() public {
        uint8 _decimals = 8;

        // we have 8 decimals, so with higher amount, we should get similar results as for 18
        // they wil not match 100% because we crating fragmented borrow amount
        _setUp(1e10, _decimals);

        vm.warp(block.timestamp + 1);
        uint256 interest = silo1.accrueInterest();

        (uint160 daoAndDeployerRevenue,, uint64 interestFraction,,,) = silo1.getSiloStorage();
        emit log_named_uint("interest", interest);
        emit log_named_uint("interestFraction", interestFraction);
        emit log_named_uint("daoAndDeployerRevenue", daoAndDeployerRevenue);

        assertEq(interest, 1109842720, "interest");
        assertEq(interestFraction, 502466316910034951, "expect interestFraction");

        assertEq(daoAndDeployerRevenue, 277460680_000000000000000000, "expect daoAndDeployerRevenue");

        vm.expectEmit(address(silo1));
        uint256 daoFees = 166476408;
        uint256 deployerFees = 110984272;
        emit ISilo.WithdrawnFeed(daoFees, deployerFees);
        silo1.withdrawFees();
    }

    /*
    forge test -vv --ffi --mt test_fee_oneToken_6
    */
    function test_fee_oneToken_6() public {
        uint8 _decimals = 8;

        _setUp(1, _decimals);

        uint160 prevDaoAndDeployerRevenue;
        uint64 prevInterestFraction;
        uint64 prevInterest;

        for (uint t = 1; t < 365 days; t++) {
            vm.warp(block.timestamp + 1);
            uint256 interest = silo1.accrueInterest();

            if (interest != 0) {
                emit log_named_uint("we got interest after s", t);
                break;
            }

            (uint160 daoAndDeployerRevenue,, uint64 interestFraction,,,) = silo1.getSiloStorage();
            emit log_named_uint(string.concat("#", Strings.toString(t), " interest"), interest);
            emit log_named_uint(string.concat("#", Strings.toString(t), " interestFraction"), interestFraction);
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
                interestFraction,
                prevInterestFraction,
                string.concat("#", Strings.toString(t), "prevInterestFraction incrementing")
            );

            prevDaoAndDeployerRevenue = daoAndDeployerRevenue;
            prevInterestFraction = interestFraction;

            vm.expectRevert();
            silo1.withdrawFees();
        }

        uint256 interest = silo1.accrueInterest();

        (uint160 daoAndDeployerRevenue,, uint64 interestFraction,,,) = silo1.getSiloStorage();
        emit log_named_uint("#final interest", interest);
        emit log_named_uint("#final interestFraction", interestFraction);
        emit log_named_uint("#final daoAndDeployerRevenue", daoAndDeployerRevenue);

        assertGt(daoAndDeployerRevenue, prevDaoAndDeployerRevenue, "prevDaoAndDeployerRevenue incrementing");

        assertLt(
            interestFraction,
            prevInterestFraction,
            "prevInterestFraction is result of modulo, so once we got interest it should circle-drop"
        );

        // TODO write test where we check if accru every second == one accrute after year
        for (uint t = 1; t < 365 days; t++) {
            vm.warp(block.timestamp + 1);
            silo1.accrueInterest();

            (prevDaoAndDeployerRevenue,,,,,) = silo1.getSiloStorage();

            vm.expectEmit(address(silo1));
            emit ISilo.WithdrawnFeed(1e18, 1e18);

            try silo1.withdrawFees() {
                emit log_named_uint("we got daoAndDeployerRevenue after s", t);
                emit log_named_decimal_uint("# daoAndDeployerRevenue", prevDaoAndDeployerRevenue, 18);
                break;
            } catch {
                // keep going until we have enough for both receivers
            }
        }

        (daoAndDeployerRevenue,,,,,) = silo1.getSiloStorage();
        assertLt(daoAndDeployerRevenue, 1e18, "[daoAndDeployerRevenue] only fraction left < 1e18");

        //
        // assertEq((daoBalance + deployerBalance) * 1e18 + daoAndDeployerRevenue, prevDaoAndDeployerRevenue, "proper fees calculation");
    }

    function _fragmentedAmount(uint256 _amount, uint8 _decimals) internal pure returns (uint256) {
        for (uint i; i < _decimals; i++) {
            _amount +=  10 ** i;
        }

        return _amount;
    }
}
