// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {Actions} from "silo-core/contracts/lib/Actions.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";

import {SiloConfigMock} from "../../_mocks/SiloConfigMock.sol";
import {SiloFactoryMock} from "../../_mocks/SiloFactoryMock.sol";
import {TokenHelper} from "../TokenHelper.t.sol";
import {TokenMock} from "../../_mocks/TokenMock.sol";

// forge test -vv --ffi --mc WithdrawFeesTest
contract WithdrawFeesTest is Test {
    ISilo.SiloData public siloData;
    ISiloConfig public config;
    ISiloFactory public factory;


    SiloConfigMock siloConfig;
    SiloFactoryMock siloFactory;
    TokenMock token;

    function setUp() public {
        siloConfig = new SiloConfigMock(address(0));
        config = ISiloConfig(siloConfig.ADDRESS());

        siloFactory = new SiloFactoryMock(address(0));
        factory = ISiloFactory(siloFactory.ADDRESS());

        token = new TokenMock(makeAddr("Asset"));
    }

    /*
    forge test -vv --mt test_withdrawFees_revert_WhenNoData
    */
    function test_withdrawFees_revert_WhenNoData() external {
        _reset();

        vm.expectRevert();
        _withdrawFees(ISilo(address(this)), siloData);
    }

    /*
    forge test -vv --mt test_withdrawFees_revert_zeros
    */
    function test_withdrawFees_revert_zeros() external {
        uint256 daoFee;
        uint256 deployerFee;
        uint256 flashloanFeeInBp;
        address asset = token.ADDRESS();

        address dao;
        address deployer;
        
        siloConfig.getFeesWithAssetMock(address(this), daoFee, deployerFee, flashloanFeeInBp, asset);
        siloFactory.getFeeReceiversMock(address(this), dao, deployer);
        token.balanceOfMock(address(this), 0);

        vm.expectRevert(ISilo.BalanceZero.selector);
        _withdrawFees(ISilo(address(this)), siloData);
    }

    /*
    forge test -vv --mt test_withdrawFees_EarnedZero
    */
    function test_withdrawFees_EarnedZero() external {
        uint256 daoFee;
        uint256 deployerFee;
        uint256 flashloanFeeInBp;
        address asset = token.ADDRESS();

        address dao;
        address deployer;
        
        siloConfig.getFeesWithAssetMock(address(this), daoFee, deployerFee, flashloanFeeInBp, asset);
        siloFactory.getFeeReceiversMock(address(this), dao, deployer);
        token.balanceOfMock(address(this), 1);

        vm.expectRevert(ISilo.EarnedZero.selector);
        _withdrawFees(ISilo(address(this)), siloData);
    }

    /*
    forge test -vv --mt test_withdrawFees_NothingToPay
    */
    function test_withdrawFees_NothingToPay() external {
        uint256 daoFee;
        uint256 deployerFee;
        uint256 flashloanFeeInBp;
        address asset = token.ADDRESS();

        address dao;
        address deployer;
        
        siloConfig.getFeesWithAssetMock(address(this), daoFee, deployerFee, flashloanFeeInBp, asset);
        siloFactory.getFeeReceiversMock(address(this), dao, deployer);
        token.balanceOfMock(address(this), 1);

        siloData.daoAndDeployerFees = 2;

        vm.expectRevert(ISilo.NothingToPay.selector);
        _withdrawFees(ISilo(address(this)), siloData);
    }

    /*
    forge test -vv --mt test_withdrawFees_when_deployerFeeReceiver_isZero
    */
    function test_withdrawFees_when_deployerFeeReceiver_isZero() external {
        uint256 daoFee;
        uint256 deployerFee;
        uint256 flashloanFeeInBp;
        address asset = token.ADDRESS();

        address dao = makeAddr("DAO");
        address deployer;

        siloConfig.getFeesWithAssetMock(address(this), daoFee, deployerFee, flashloanFeeInBp, asset);
        siloFactory.getFeeReceiversMock(address(this), dao, deployer);
        token.balanceOfMock(address(this), 1e18);

        siloData.daoAndDeployerFees = 9;

        token.transferMock(dao, 9);

        _withdrawFees(ISilo(address(this)), siloData);
    }

    /*
    forge test -vv --mt test_withdrawFees_when_daoFeeReceiver_isZero
    */
    function test_withdrawFees_when_daoFeeReceiver_isZero() external {
        uint256 daoFee;
        uint256 deployerFee;
        uint256 flashloanFeeInBp;
        address asset = token.ADDRESS();

        address dao;
        address deployer = makeAddr("Deployer");

        siloConfig.getFeesWithAssetMock(address(this), daoFee, deployerFee, flashloanFeeInBp, asset);
        siloFactory.getFeeReceiversMock(address(this), dao, deployer);
        token.balanceOfMock(address(this), 1e18);

        siloData.daoAndDeployerFees = 2;

        token.transferMock(deployer, 2);

        _withdrawFees(ISilo(address(this)), siloData);
    }

    /*
    forge test -vv --mt test_withdrawFees_pass
    */
    function test_withdrawFees_pass() external {
        uint256 daoFee = 0.20e18;
        uint256 deployerFee = 0.20e18;
        uint256 daoAndDeployerFees = 1e18;
        uint256 daoFees = daoAndDeployerFees/2;

        _withdrawFees_pass(daoFee, deployerFee, daoFees, daoAndDeployerFees - daoFees);

        daoFee = 0.20e18;
        deployerFee = 0.10e18;
        daoFees = daoAndDeployerFees * 2/3;
        _withdrawFees_pass(daoFee, deployerFee, daoFees, daoAndDeployerFees - daoFees);

        daoFee = 0.20e18;
        deployerFee = 0.01e18;
        daoFees = daoAndDeployerFees * 20/21;
        _withdrawFees_pass(daoFee, deployerFee, daoFees, daoAndDeployerFees - daoFees);
    }

    function _withdrawFees_pass(
        uint256 _daoFee,
        uint256 _deployerFee,
        uint256 _transferDao,
        uint256 _transferDeployer
    )
        internal
    {
        uint256 flashloanFeeInBp;
        address asset = token.ADDRESS();

        address dao = makeAddr("DAO");
        address deployer = makeAddr("Deployer");

        siloConfig.getFeesWithAssetMock(address(this), _daoFee, _deployerFee, flashloanFeeInBp, asset);
        siloFactory.getFeeReceiversMock(address(this), dao, deployer);
        token.balanceOfMock(address(this), 999e18);

        siloData.daoAndDeployerFees = 1e18;

        if (_transferDao != 0) token.transferMock(dao, _transferDao);
        if (_transferDeployer != 0) token.transferMock(deployer, _transferDeployer);

        _withdrawFees(ISilo(address(this)), siloData);
        assertEq(siloData.daoAndDeployerFees, 0, "fees cleared");
    }

    function _withdrawFees(ISilo _silo, ISilo.SiloData storage _siloData) internal {
        Actions.withdrawFees(_silo, _siloData);
    }

    function _reset() internal {
        config = ISiloConfig(address(0));
        factory = ISiloFactory(address(0));
        delete siloData;
    }
}
