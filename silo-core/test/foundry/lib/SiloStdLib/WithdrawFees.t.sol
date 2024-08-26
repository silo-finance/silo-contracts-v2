// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {Actions} from "silo-core/contracts/lib/Actions.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {SiloStorageLib} from "silo-core/contracts/lib/SiloStorageLib.sol";
import {AssetTypes} from "silo-core/contracts/lib/AssetTypes.sol";

import {SiloConfigMock} from "../../_mocks/SiloConfigMock.sol";
import {SiloFactoryMock} from "../../_mocks/SiloFactoryMock.sol";
import {TokenHelper} from "../TokenHelper.t.sol";
import {TokenMock} from "../../_mocks/TokenMock.sol";

// forge test -vv --ffi --mc WithdrawFeesTest
contract WithdrawFeesTest is Test {
    uint256 constant public NO_PROTECTED_ASSETS = 0;

    ISiloConfig public config;
    ISiloFactory public factory;


    SiloConfigMock siloConfig;
    SiloFactoryMock siloFactory;
    TokenMock token;

    function _$() internal returns (ISilo.SiloStorage storage) {
        return SiloStorageLib.getSiloStorage();
    }

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
        _withdrawFees(ISilo(address(this)));
    }

    /*
    forge test -vv --mt test_withdrawFees_revert_NoLiquidity
    */
    function test_withdrawFees_revert_NoLiquidity() external {
        _$().daoAndDeployerFees = 1;

        uint256 daoFee;
        uint256 deployerFee;
        uint256 flashloanFeeInBp;
        address asset = token.ADDRESS();

        address dao;
        address deployer;

        siloConfig.getFeesWithAssetMock(address(this), daoFee, deployerFee, flashloanFeeInBp, asset);
        siloFactory.getFeeReceiversMock(address(this), dao, deployer);
        token.balanceOfMock(address(this), 0);
        _setProtectedAssets(NO_PROTECTED_ASSETS);

        vm.expectRevert(ISilo.NoLiquidity.selector);
        _withdrawFees(ISilo(address(this)));
    }

    /*
    forge test -vv --mt test_withdrawFees_EarnedZero
    */
    function test_withdrawFees_EarnedZero() external {
        _setProtectedAssets(NO_PROTECTED_ASSETS);

        vm.expectRevert(ISilo.EarnedZero.selector);
        _withdrawFees(ISilo(address(this)));
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

        _$().daoAndDeployerFees = 2;
        _setProtectedAssets(NO_PROTECTED_ASSETS);

        vm.expectRevert(ISilo.NothingToPay.selector);
        _withdrawFees(ISilo(address(this)));
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

        _$().daoAndDeployerFees = 9;

        token.transferMock(dao, 9);
        _setProtectedAssets(NO_PROTECTED_ASSETS);

        _withdrawFees(ISilo(address(this)));
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

        _$().daoAndDeployerFees = 2;

        token.transferMock(deployer, 2);
        _setProtectedAssets(NO_PROTECTED_ASSETS);

        _withdrawFees(ISilo(address(this)));
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

    /*
    forge test -vv --mt test_cant_withdraw_more_than_available
    */
    function test_cant_withdraw_more_than_available() external {
        uint256 daoFee;
        uint256 deployerFee;
        uint256 flashloanFeeInBp;
        address asset = token.ADDRESS();
        uint256 siloBalance = 1e18;

        address dao = makeAddr("DAO");
        address deployer;

        siloConfig.getFeesWithAssetMock(address(this), daoFee, deployerFee, flashloanFeeInBp, asset);
        siloFactory.getFeeReceiversMock(address(this), dao, deployer);
        token.balanceOfMock(address(this), siloBalance);

        _$().daoAndDeployerFees = uint192(siloBalance); // fees are the same as balance

        uint256 protectedAssets = siloBalance / 3; // the third part of the balance is protected

        token.transferMock(dao, siloBalance - protectedAssets); // dao gets all the liquidity except protected assets
        _setProtectedAssets(protectedAssets);

        _withdrawFees(ISilo(address(this)));
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

        _$().daoAndDeployerFees = 1e18;

        if (_transferDao != 0) token.transferMock(dao, _transferDao);
        if (_transferDeployer != 0) token.transferMock(deployer, _transferDeployer);

        _setProtectedAssets(NO_PROTECTED_ASSETS);
        _withdrawFees(ISilo(address(this)));
        assertEq(_$().daoAndDeployerFees, 0, "fees cleared");
    }

    function _withdrawFees(ISilo _silo) internal {
        Actions.withdrawFees(_silo);
    }

    function _setProtectedAssets(uint256 _assets) internal {
        _$().total[AssetTypes.PROTECTED] = _assets;
    }

    function _reset() internal {
        _setProtectedAssets(NO_PROTECTED_ASSETS);

        config = ISiloConfig(address(0));
        factory = ISiloFactory(address(0));
        _$().daoAndDeployerFees = 0;
        _$().interestRateTimestamp = 0;
    }
}
