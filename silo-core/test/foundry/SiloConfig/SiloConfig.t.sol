// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig, SiloConfig} from "silo-core/contracts/SiloConfig.sol";

/*
forge test -vv --mc SiloConfigTest
*/
contract SiloConfigTest is Test {
    address wrongSilo = address(10000000001);
    SiloConfig _siloConfig;

    function setUp() public {
        ISiloConfig.ConfigData memory _configData0;
        _configData0.silo = makeAddr("silo0");
        _configData0.token = makeAddr("token0");
        _configData0.debtShareToken = makeAddr("debtShareToken0");

        ISiloConfig.ConfigData memory _configData1;
        _configData1.silo = makeAddr("silo1");
        _configData1.token = makeAddr("token1");
        _configData1.debtShareToken = makeAddr("debtShareToken1");

        _siloConfig = siloConfigDeploy(1, _configData0, _configData1);
    }

    function siloConfigDeploy(
        uint256 _siloId,
        ISiloConfig.ConfigData memory _configData0,
        ISiloConfig.ConfigData memory _configData1
    ) public returns (SiloConfig siloConfig) {
        vm.assume(_configData0.silo != wrongSilo);
        vm.assume(_configData1.silo != wrongSilo);
        vm.assume(_configData0.silo != _configData1.silo);

        _configData0.liquidationModule = _configData1.liquidationModule; // when using assume, it reject too many inputs

        _configData0.otherSilo = _configData1.silo;
        _configData1.otherSilo = _configData0.silo;
        _configData1.daoFee = _configData0.daoFee;
        _configData1.deployerFee = _configData0.deployerFee;

        siloConfig = new SiloConfig(_siloId, _configData0, _configData1);
    }

    /*
    forge test -vv --mt test_getSilos_fuzz
    */
    function test_getSilos_fuzz(
        uint256 _siloId,
        ISiloConfig.ConfigData memory _configData0,
        ISiloConfig.ConfigData memory _configData1
    ) public {
        SiloConfig siloConfig = siloConfigDeploy(_siloId, _configData0, _configData1);

        (address silo0, address silo1) = siloConfig.getSilos();
        assertEq(silo0, _configData0.silo);
        assertEq(silo1, _configData1.silo);
    }

    /*
    forge test -vv --mt test_getShareTokens_fuzz
    */
    function test_getShareTokens_fuzz(
        uint256 _siloId,
        ISiloConfig.ConfigData memory _configData0,
        ISiloConfig.ConfigData memory _configData1
    ) public {
        SiloConfig siloConfig = siloConfigDeploy(_siloId, _configData0, _configData1);

        vm.expectRevert(ISiloConfig.WrongSilo.selector);
        siloConfig.getShareTokens(wrongSilo);

        (address protectedShareToken, address collateralShareToken, address debtShareToken) = siloConfig.getShareTokens(_configData0.silo);
        assertEq(protectedShareToken, _configData0.protectedShareToken);
        assertEq(collateralShareToken, _configData0.collateralShareToken);
        assertEq(debtShareToken, _configData0.debtShareToken);

        (protectedShareToken, collateralShareToken, debtShareToken) = siloConfig.getShareTokens(_configData1.silo);
        assertEq(protectedShareToken, _configData1.protectedShareToken);
        assertEq(collateralShareToken, _configData1.collateralShareToken);
        assertEq(debtShareToken, _configData1.debtShareToken);
    }

    /*
    forge test -vv --mt test_getAssetForSilo_fuzz
    */
    function test_getAssetForSilo_fuzz(
        uint256 _siloId,
        ISiloConfig.ConfigData memory _configData0,
        ISiloConfig.ConfigData memory _configData1
    ) public {
        SiloConfig siloConfig = siloConfigDeploy(_siloId, _configData0, _configData1);

        vm.expectRevert(ISiloConfig.WrongSilo.selector);
        siloConfig.getAssetForSilo(wrongSilo);

        assertEq(siloConfig.getAssetForSilo(_configData0.silo), _configData0.token);
        assertEq(siloConfig.getAssetForSilo(_configData1.silo), _configData1.token);
    }

    /*
    forge test -vv --mt test_getConfigs_fuzz
    */
    function test_getConfigs_fuzz(
        uint256 _siloId,
        ISiloConfig.ConfigData memory _configData0,
        ISiloConfig.ConfigData memory _configData1
    ) public {
        SiloConfig siloConfig = siloConfigDeploy(_siloId, _configData0, _configData1);

        vm.expectRevert(ISiloConfig.WrongSilo.selector);
        siloConfig.getConfigs(wrongSilo, address(0), 0 /* always 0 for external calls */);

        (
            ISiloConfig.ConfigData memory c0,
            ISiloConfig.ConfigData memory c1,
        ) = siloConfig.getConfigs(_configData0.silo, address(0), 0 /* always 0 for external calls */);
        
        assertEq(keccak256(abi.encode(c0)), keccak256(abi.encode(_configData0)));
        assertEq(keccak256(abi.encode(c1)), keccak256(abi.encode(_configData1)));
    }

    /*
    forge test -vv --mt test_getConfig_fuzz
    */
    function test_getConfig_fuzz(
        uint256 _siloId,
        ISiloConfig.ConfigData memory _configData0,
        ISiloConfig.ConfigData memory _configData1
    ) public {
        SiloConfig siloConfig = siloConfigDeploy(_siloId, _configData0, _configData1);

        vm.expectRevert(ISiloConfig.WrongSilo.selector);
        siloConfig.getConfig(wrongSilo);

        ISiloConfig.ConfigData memory c0 = siloConfig.getConfig(_configData0.silo);
        assertEq(keccak256(abi.encode(c0)), keccak256(abi.encode(_configData0)));

        ISiloConfig.ConfigData memory c1 = siloConfig.getConfig(_configData1.silo);
        assertEq(keccak256(abi.encode(c1)), keccak256(abi.encode(_configData1)));
    }

    /*
    forge test -vv --mt test_getFeesWithAsset_fuzz
    */
    function test_getFeesWithAsset_fuzz(
        uint256 _siloId,
        ISiloConfig.ConfigData memory _configData0,
        ISiloConfig.ConfigData memory _configData1
    ) public {
        SiloConfig siloConfig = siloConfigDeploy(_siloId, _configData0, _configData1);

        vm.expectRevert(ISiloConfig.WrongSilo.selector);
        siloConfig.getFeesWithAsset(wrongSilo);

        (uint256 daoFee, uint256 deployerFee, uint256 flashloanFee, address asset) = siloConfig.getFeesWithAsset(_configData0.silo);
        
        assertEq(daoFee, _configData0.daoFee);
        assertEq(deployerFee, _configData0.deployerFee);
        assertEq(flashloanFee, _configData0.flashloanFee);
        assertEq(asset, _configData0.token);

        (daoFee, deployerFee, flashloanFee, asset) = siloConfig.getFeesWithAsset(_configData1.silo);
        
        assertEq(daoFee, _configData1.daoFee);
        assertEq(deployerFee, _configData1.deployerFee);
        assertEq(flashloanFee, _configData1.flashloanFee);
        assertEq(asset, _configData1.token);
    }

    /*
    forge test -vv --mt test_openDebt_revertOnWrongSilo
    */
    function test_openDebt_revertOnWrongSilo() public {
        vm.expectRevert(ISiloConfig.WrongSilo.selector);
        _siloConfig.openDebt(address(1), false);
    }

    /*
    forge test -vv --mt test_openDebt_pass
    */
    function test_openDebt_pass() public {
        vm.prank(makeAddr("silo0"));
        _siloConfig.openDebt(address(1), false);

        // counter example
        vm.prank(makeAddr("silo1"));
        _siloConfig.openDebt(address(2), false);
    }

    /*
    forge test -vv --mt test_getConfigs_zero
    */
    function test_getConfigs_zero() public {
        address silo = makeAddr("silo0");

        (
            ISiloConfig.ConfigData memory siloConfig,
            ISiloConfig.ConfigData memory otherSiloConfig,
            ISiloConfig.DebtInfo memory debtInfo
        ) = _siloConfig.getConfigs(silo, address(0), 0 /* always 0 for external calls */);

        ISiloConfig.DebtInfo memory positionEmpty;

        assertEq(siloConfig.silo, silo, "first config should be for silo");
        assertEq(otherSiloConfig.silo, makeAddr("silo1"));
        assertEq(abi.encode(positionEmpty), abi.encode(debtInfo), "debtInfo should be empty");
    }

    /*
    forge test -vv --mt test_openDebt_debtInThisSilo
    */
    function test_openDebt_skipsIfAlreadyOpen() public {
        address silo = makeAddr("silo0");
        address borrower = makeAddr("borrower");
        bool singleAsset = true;

        vm.prank(silo);
        (,, ISiloConfig.DebtInfo memory positionInfo1) = _siloConfig.openDebt(borrower, singleAsset);

        vm.prank(silo);
        (,, ISiloConfig.DebtInfo memory positionInfo2) = _siloConfig.openDebt(borrower, singleAsset);

        assertEq(abi.encode(positionInfo1), abi.encode(positionInfo2), "nothing should change");
    }

    /*
    forge test -vv --mt test_openDebt_debtInThisSilo
    */
    function test_openDebt_debtInThisSilo() public {
        address silo = makeAddr("silo0");
        address borrower = makeAddr("borrower");
        bool singleAsset = true;

        vm.prank(silo);
        (,, ISiloConfig.DebtInfo memory debtInfo) = _siloConfig.openDebt(borrower, singleAsset);

        assertTrue(debtInfo.positionOpen);
        assertTrue(debtInfo.singleAsset == singleAsset);
        assertTrue(debtInfo.debtInSilo0);
        assertTrue(debtInfo.debtInThisSilo);
    }

    /*
    forge test -vv --mt test_openDebt_debtInOtherSilo
    */
    function test_openDebt_debtInOtherSilo() public {
        address silo = makeAddr("silo0");
        address borrower = makeAddr("borrower");
        bool singleAsset;

        vm.prank(makeAddr("silo1"));
        _siloConfig.openDebt(borrower, singleAsset);

        (
            ,, ISiloConfig.DebtInfo memory debtInfo
        ) = _siloConfig.getConfigs(silo, borrower, 0 /* always 0 for external calls */);

        assertTrue(debtInfo.positionOpen);
        assertTrue(debtInfo.singleAsset == singleAsset);
        assertTrue(!debtInfo.debtInSilo0);
        assertTrue(!debtInfo.debtInThisSilo);

        (,, debtInfo) = _siloConfig.getConfigs(silo, address(1), 0 /* always 0 for external calls */);
        ISiloConfig.DebtInfo memory positionEmpty;

        assertEq(abi.encode(positionEmpty), abi.encode(debtInfo), "debtInfo should be empty");
    }

    /*
    forge test -vv --mt test_onDebtTransfer_revertOnCrossSilo
    */
    function test_onDebtTransfer_revertOnCrossSilo() public {
        address from = makeAddr("from");
        address to = makeAddr("to");
        bool singleAsset;

        vm.prank(makeAddr("silo0"));
        _siloConfig.openDebt(from, singleAsset);

        vm.prank(makeAddr("debtShareToken1"));
        vm.expectRevert(ISiloConfig.PositionExistInOtherSilo.selector);
        _siloConfig.onDebtTransfer(from, to);
    }

    /*
    forge test -vv --mt test_onDebtTransfer_clone
    */
    /// forge-config: core-test.fuzz.runs = 10
    function test_onDebtTransfer_clone_fuzz(bool _silo0, bool singleAsset) public {
        address silo = _silo0 ? makeAddr("silo0") : makeAddr("silo1");
        address from = makeAddr("from");
        address to = makeAddr("to");

        vm.prank(silo);
        (,, ISiloConfig.DebtInfo memory positionFrom) = _siloConfig.openDebt(from, singleAsset);

        vm.prank(_silo0 ? makeAddr("debtShareToken0") : makeAddr("debtShareToken1"));
        _siloConfig.onDebtTransfer(from, to);

        (
            ,, ISiloConfig.DebtInfo memory positionTo
        ) = _siloConfig.getConfigs(silo, to, 0 /* always 0 for external calls */);

        assertEq(abi.encode(positionFrom), abi.encode(positionTo), "debt should be same if called for same silo");
    }

    /*
    forge test -vv --mt test_onDebtTransfer_revertIfNotDebtToken
    */
    function test_onDebtTransfer_revertIfNotDebtToken() public {
        address silo = makeAddr("silo1");
        address from = makeAddr("from");
        address to = makeAddr("to");

        vm.prank(silo);
        vm.expectRevert(ISiloConfig.OnlyDebtShareToken.selector);
        _siloConfig.onDebtTransfer(from, to);
    }

    /*
    forge test -vv --mt test_onDebtTransfer_PositionExistInOtherSilo
    */
    function test_onDebtTransfer_PositionExistInOtherSilo() public {
        address debtShareToken0 = makeAddr("debtShareToken0");
        address debtShareToken1 = makeAddr("debtShareToken1");
        address from = makeAddr("from");
        address to = makeAddr("to");

        bool singleAsset = true;

        vm.prank(makeAddr("silo0"));
        _siloConfig.openDebt(from, singleAsset);

        vm.prank(makeAddr("silo1"));
        _siloConfig.openDebt(to, singleAsset);

        vm.prank(debtShareToken0);
        vm.expectRevert(ISiloConfig.PositionExistInOtherSilo.selector);
        _siloConfig.onDebtTransfer(from, to);

        vm.prank(debtShareToken0);
        // this will pass, because `from` has debt in 0
        _siloConfig.onDebtTransfer(to, from);

        vm.prank(debtShareToken1);
        // this will pass, because `to` has debt in 1
        _siloConfig.onDebtTransfer(from, to);

        vm.prank(debtShareToken1);
        vm.expectRevert(ISiloConfig.PositionExistInOtherSilo.selector);
        _siloConfig.onDebtTransfer(to, from);
    }

    /*
    forge test -vv --mt test_onDebtTransfer_pass
    */
    function test_onDebtTransfer_pass() public {
        address debtShareToken0 = makeAddr("debtShareToken0");
        address from = makeAddr("from");
        address to = makeAddr("to");

        bool sameAsset = true;

        vm.prank(makeAddr("silo0"));
        _siloConfig.openDebt(from, sameAsset);

        vm.prank(makeAddr("silo0"));
        _siloConfig.openDebt(to, !sameAsset);

        vm.prank(debtShareToken0);
        _siloConfig.onDebtTransfer(from, to);

        (
            ,, ISiloConfig.DebtInfo memory positionTo
        ) = _siloConfig.getConfigs(makeAddr("silo1"), to, 0 /* always 0 for external calls */);

        assertTrue(positionTo.positionOpen, "positionOpen");
        assertTrue(!positionTo.singleAsset, "singleAsset is not cloned when debt already open");
        assertTrue(positionTo.debtInSilo0, "debtInSilo0");
        assertTrue(!positionTo.debtInThisSilo, "call is from silo1, so debt should not be in THIS silo");
    }

    /*
    forge test -vv --mt test_closeDebt_revert
    */
    function test_closeDebt_revert() public {
        vm.expectRevert(ISiloConfig.WrongSilo.selector);
        _siloConfig.closeDebt(address(0));
    }

    /*
    forge test -vv --mt test_closeDebt_pass
    */
    function test_closeDebt_pass() public {
        address silo = makeAddr("silo1");
        address borrower = makeAddr("borrower");

        bool singleAsset = true;

        vm.prank(makeAddr("silo1"));
        _siloConfig.openDebt(borrower, singleAsset);

        vm.prank(makeAddr("silo0")); // other silo can close debt
        _siloConfig.closeDebt(borrower);

        ISiloConfig.DebtInfo memory positionEmpty;
        (
            ,, ISiloConfig.DebtInfo memory debt
        ) = _siloConfig.getConfigs(silo, borrower, 0 /* always 0 for external calls */);
        assertEq(abi.encode(positionEmpty), abi.encode(debt), "debt should be deleted");
    }
}
