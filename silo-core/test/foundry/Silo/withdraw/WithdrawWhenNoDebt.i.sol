// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {TokenMock} from "silo-core/test/foundry/_mocks/TokenMock.sol";
import {SiloFixture_ETH_USDC} from "../../_common/fixtures/SiloFixture_ETH_USDC.sol";

/*
    forge test -vv --mc WithdrawWhenNoDebtTest
*/
contract WithdrawWhenNoDebtTest is IntegrationTest {
    uint256 internal constant _BASIS_POINTS = 1e4;
    uint256 internal constant _FORKING_BLOCK_NUMBER = 17336000;

    ISiloConfig siloConfig;
    ISilo silo0;
    ISilo silo1;

    TokenMock token0;
    TokenMock token1;

    function setUp() public {
        vm.createSelectFork(getChainRpcUrl(MAINNET_ALIAS), _FORKING_BLOCK_NUMBER);

        SiloFixture_ETH_USDC siloFixture = new SiloFixture_ETH_USDC();
        (siloConfig, silo0, silo1, token0, token1) = siloFixture.deploy(vm);
    }

    /*
    forge test -vv --mt test_withdraw_all_Collateral
    */
    function test_withdraw_all_Collateral() public {
        _deposit(address(this), 2e18, ISilo.AssetType.Collateral);
        _deposit(address(this), 1e18, ISilo.AssetType.Protected);

        (address protectedShareToken, address collateralShareToken, address debtShareToken) = siloConfig.getShareTokens(address(silo0));
        uint256 sharesBefore = IShareToken(collateralShareToken).balanceOf(address(this));

        assertEq(silo0.maxWithdraw(address(this)), 2e18, "available collateral");

        uint256 gotShares = _withdraw(address(this), 2e18, ISilo.AssetType.Collateral);

        assertEq(IShareToken(debtShareToken).balanceOf(address(this)), 0, "debtShareToken");
        assertEq(IShareToken(protectedShareToken).balanceOf(address(this)), 1e18, "protectedShareToken stays the same");
        assertEq(IShareToken(collateralShareToken).balanceOf(address(this)), 0, "collateral burned");
        assertEq(gotShares, sharesBefore, "withdraw all shares");

        assertEq(silo0.getCollateralAssets(), 0, "CollateralAssets should be withdrawn");
    }

    /*
    forge test -vv --mt test_withdraw_all_Protected
    */
    function test_withdraw_all_Protected() public {
        _deposit(address(this), 2e18, ISilo.AssetType.Collateral);
        _deposit(address(this), 1e18, ISilo.AssetType.Protected);

        (address protectedShareToken, address collateralShareToken, address debtShareToken) = siloConfig.getShareTokens(address(silo0));
        uint256 sharesBefore = IShareToken(protectedShareToken).balanceOf(address(this));

        assertEq(silo0.maxWithdraw(address(this)), 2e18, "available collateral");

        uint256 gotShares = _withdraw(address(this), 1e18, ISilo.AssetType.Protected);

        assertEq(silo0.maxWithdraw(address(this)), 2e18, "available collateral");

        assertEq(IShareToken(debtShareToken).balanceOf(address(this)), 0, "debtShareToken");
        assertEq(IShareToken(protectedShareToken).balanceOf(address(this)), 0, "protectedShareToken stays the same");
        assertEq(IShareToken(collateralShareToken).balanceOf(address(this)), 2e18, "collateral burned");
        assertEq(gotShares, sharesBefore, "withdraw all shares");

        assertEq(silo0.getProtectedAssets(), 0, "protected Assets should be withdrawn");
    }

    /*
    forge test -vv --mt test_withdraw_scenario_oneUser
    */
    function test_withdraw_scenario_oneUser() public {
        _deposit(address(this), 2e18, ISilo.AssetType.Collateral);
        _deposit(address(this), 1e18, ISilo.AssetType.Protected);

        _userWithdrawing();
    }

    /*
    forge test -vv --mt test_withdraw_scenario_manyUsers
    */
    function test_withdraw_scenario_manyUsers() public {
        _deposit(address(5555), 1, ISilo.AssetType.Protected);
        _deposit(address(6666), 1, ISilo.AssetType.Collateral);


        _deposit(address(this), 2e18, ISilo.AssetType.Collateral);
        _deposit(address(this), 1e18, ISilo.AssetType.Protected);

        _userWithdrawing();

        _deposit(address(3344), 11e18, ISilo.AssetType.Protected);
        _deposit(address(3344), 22e18, ISilo.AssetType.Collateral);

        _deposit(address(this), 2e18, ISilo.AssetType.Collateral);
        _deposit(address(this), 1e18, ISilo.AssetType.Protected);

        _userWithdrawing();

        assertEq(silo0.getProtectedAssets(), 11e18 + 1, "protected Assets should be withdrawn");
        assertEq(silo0.getCollateralAssets(), 22e18 + 1, "protected Assets should be withdrawn");
    }

    /*
    forge test -vv --mt test_withdraw_scenarios_fuzz
    */
    function test_withdraw_scenarios_fuzz(uint256 _deposit1, uint256 _deposit2, uint256 _deposit3) public {
        vm.assume(_deposit1 != 0 && _deposit1 < 2 ** 128);
        vm.assume(_deposit2 != 0 && _deposit2 < 2 ** 128);
        vm.assume(_deposit3 != 0 && _deposit3 < 2 ** 128);

        _deposit(address(1), _deposit1, ISilo.AssetType.Protected);
        _deposit(address(1), _deposit1, ISilo.AssetType.Collateral);

        _deposit(address(2), _deposit2, ISilo.AssetType.Protected);
        _deposit(address(2), _deposit2, ISilo.AssetType.Collateral);

        _deposit(address(3), _deposit3, ISilo.AssetType.Protected);
        _deposit(address(3), _deposit3, ISilo.AssetType.Collateral);


        _withdraw(address(1), _deposit1, ISilo.AssetType.Protected);
        _withdraw(address(1), _deposit1, ISilo.AssetType.Collateral);

        _withdraw(address(2), _deposit2, ISilo.AssetType.Protected);
        _withdraw(address(2), _deposit2, ISilo.AssetType.Collateral);

        _withdraw(address(3), _deposit3, ISilo.AssetType.Protected);
        _withdraw(address(3), _deposit3, ISilo.AssetType.Collateral);


        assertEq(silo0.getProtectedAssets(), 0, "protected Assets should be withdrawn");
        assertEq(silo0.getCollateralAssets(), 0, "protected Assets should be withdrawn");
    }

    function _userWithdrawing() internal {
        (address protectedShareToken, address collateralShareToken, address debtShareToken) = siloConfig.getShareTokens(address(silo0));

        assertEq(silo0.maxWithdraw(address(this)), 2e18, "available collateral #1");

        uint256 gotShares = _withdraw(address(this), 0.1e18, ISilo.AssetType.Protected);
        assertEq(gotShares, 0.1e18, "withdraw 0.1e18");
        assertEq(silo0.maxWithdraw(address(this)), 2e18, "available collateral #2");

        gotShares = _withdraw(address(this), 0.1e18, ISilo.AssetType.Collateral);
        assertEq(gotShares, 0.1e18, "withdraw 0.1e18");
        assertEq(silo0.maxWithdraw(address(this)), 1.9e18, "available collateral #3");

        gotShares = _withdraw(address(this), 123456781234567893, ISilo.AssetType.Protected);
        assertEq(gotShares, 123456781234567893, "withdraw 123456781234567893 P");
        assertEq(silo0.maxWithdraw(address(this)), 1.9e18, "available collateral #4");

        gotShares = _withdraw(address(this), 123456781234567893, ISilo.AssetType.Collateral);
        assertEq(gotShares, 123456781234567893, "withdraw 123456781234567893 C");
        assertEq(silo0.maxWithdraw(address(this)), 1.9e18 - 123456781234567893, "available collateral #5");

        gotShares = _withdraw(address(this), silo0.maxWithdraw(address(this)), ISilo.AssetType.Collateral);
        assertEq(gotShares, 1.9e18 - 123456781234567893, "max withdraw");
        assertEq(silo0.maxWithdraw(address(this)), 0, "available collateral #6");

        gotShares = _withdraw(address(this), 1e18 - 0.1e18 - 123456781234567893, ISilo.AssetType.Protected);
        assertEq(gotShares, 776543218765432107, "withdraw all P");

        assertEq(IShareToken(debtShareToken).balanceOf(address(this)), 0, "debtShareToken");
        assertEq(IShareToken(protectedShareToken).balanceOf(address(this)), 0, "protectedShareToken stays the same");
        assertEq(IShareToken(collateralShareToken).balanceOf(address(this)), 0, "collateral burned");
    }


    function _deposit(address _depositor, uint256 _amount, ISilo.AssetType _type) internal {
        token0.transferFromMock(_depositor, address(silo0), _amount);
        vm.prank(_depositor);
        silo0.deposit(_amount, _depositor, _type);
    }

    function _borrow(address _borrower, uint256 _amount) internal returns (uint256 shares) {
        token0.transferFromMock(address(silo0), address(_borrower), _amount);
        vm.prank(_borrower);
        shares = silo0.withdraw(_amount, _borrower, _borrower);
    }

    function _withdraw(address _depositor, uint256 _amount, ISilo.AssetType _type) internal returns (uint256 assets){
        token0.transferFromMock(address(silo0), _depositor, _amount);
        vm.prank(_depositor);
        return silo0.withdraw(_amount, _depositor, _depositor, _type);
    }
}
