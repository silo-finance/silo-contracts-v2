// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ISilo, IERC4626} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISiloLens} from "silo-core/contracts/interfaces/ISiloLens.sol";
import {IInterestRateModel} from "silo-core/contracts/interfaces/IInterestRateModel.sol";

/*
    The following tutorial will help you to read any data from Silo protocol. Deposits, borrowed assets, liquidity,
    market setup and many more.

    $ forge test -vv --ffi --mc PublicTutorials
*/
contract PublicTutorials is Test {
    // wstETH/WETH market config.
    ISiloConfig public constant SILO_CONFIG = ISiloConfig(0x02ED2727D2Dc29b24E5AC9A7d64f2597CFb74bAB); 
    ISiloLens public constant SILO_LENS = ISiloLens(0xB14F20982F2d1E5933362f5A796736D9ffa220E4); 
    address public constant EXAMPLE_USER = 0x6d228Fa4daD2163056A48Fc2186d716f5c65E89A;

    // Fork Arbitrum at specific block.
    function setUp() public {
        uint256 blockToFork = 270679564;
        vm.createSelectFork(vm.envString("RPC_ARBITRUM"), blockToFork);
    }

    // Every market consists of two ERC4626 vaults unified by one setup represented by SiloConfig. In the following
    // example there are two vaults: wstETH vault and WETH vault.
    function test_getVaultAddresses() public {
        (address silo0, address silo1) = SILO_CONFIG.getSilos();

        assertEq(IERC4626(silo0).asset(), 0x5979D7b546E38E414F7E9822514be443A4800529, "Silo0 is a vault for wstETH");
        assertEq(IERC4626(silo1).asset(), 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, "Silo1 is a vault for WETH");
    }

    // Get an amount of user's deposited assets. ERC4626 shares represent regular deposits, which can be borrowed by
    // other users and generate interest. 
    function test_getMyRegularDepositAmount() public {
        (, address silo1) = SILO_CONFIG.getSilos();
        uint256 userShares = IERC4626(silo1).balanceOf(EXAMPLE_USER);
        uint256 userAssets = IERC4626(silo1).previewRedeem(userShares);

        assertEq(userAssets, 2 * 10**16, "User has 0.02 WETH deposited in the lending market");
    }

    // Get borrow APR. 10**18 current interest rate is equal to 100%/year. 
    function test_getBorrowAPR() public {
        // todo move to lens
        // get WETH Silo
        (address silo0,) = SILO_CONFIG.getSilos();

        // get config for WETH Silo
        ISiloConfig.ConfigData memory configData = SILO_CONFIG.getConfig(silo0);

        // get WETH interest rate model
        address interestRateModel0 = configData.interestRateModel;

        // get current interest rate for WETH Silo and current block timestamp
        uint256 currentBorrowInterestRate = 
            IInterestRateModel(interestRateModel0).getCurrentInterestRate(silo0, block.timestamp);

        assertEq(currentBorrowInterestRate, 72152346037824000, "Current debt interest rate is ~7.22% / year");
    }

    // Get deposit APR. 10**18 current interest rate is equal to 100%/year. 
    function test_getDepositAPR() public {
        // todo move to lens
        (address silo0,) = SILO_CONFIG.getSilos();
        ISiloConfig.ConfigData memory configData = SILO_CONFIG.getConfig(silo0);
        address interestRateModel0 = configData.interestRateModel;
    
        uint256 currentBorrowInterestRate = 
            IInterestRateModel(interestRateModel0).getCurrentInterestRate(silo0, block.timestamp);

        uint256 debtAssets = ISilo(silo0).getDebtAssets();
        uint256 collateralAssets = ISilo(silo0).getCollateralAssets();

        uint256 currentDepositInterestRate;

        if (collateralAssets != 0) {
            currentDepositInterestRate = (currentBorrowInterestRate * debtAssets / collateralAssets) * 
                (10**18 - configData.daoFee - configData.deployerFee) / 10**18;
        }

        assertEq(currentDepositInterestRate, 61019721466934077, "Current deposit interest rate is ~6.10% / year");
    }

    // Any lending protocol does not guarantee the ability to withdraw the borrowable deposit at any time, because
    // it can be borrowed by another user. That is why Silo has a protected deposits feature. Any borrower can
    // deposit in protected mode to make the deposit unborrowable by other users. Deposited funds will be used
    // only as collateral and not generate any interest. The advantage of protected deposit is an opportunity to
    // withdraw it any time.
    function test_getMyProtectedDepositsAmount() public {
        (, address silo1) = SILO_CONFIG.getSilos();
        
        (address protectedShareToken,,) = SILO_CONFIG.getShareTokens(silo1);
        uint256 userProtectedShares = IShareToken(protectedShareToken).balanceOf(EXAMPLE_USER);
        uint256 userProtectedAssets = ISilo(silo1).previewRedeem(userProtectedShares, ISilo.CollateralType.Protected);

        assertEq(userProtectedAssets, 12345 * 10**11, "User has 0.0012345 WETH protected deposit");
    }

    // SiloLens contracts can be used to get the total of regular + protected deposits per user.
    function test_getMyAllDepositsAmount() public {
        (, address silo1) = SILO_CONFIG.getSilos();
        
        uint256 userRegularAndProtectedAssets = SILO_LENS.collateralBalanceOfUnderlying(ISilo(silo1), EXAMPLE_USER);

        assertEq(
            userRegularAndProtectedAssets,
            212345 * 10**11,
            "User has ~0.0212345 wstETH in regular and protected deposits"
        );
    }

    // Example user deposits ETH collateral in silo1 and borrows wstETH in silo1. User's debt grows continuously by
    // interest rate. In the example we will calculate user's borrowed amount as an amount the user have to repay.
    function test_getMyBorrowedAmount() public {
        (address silo0,) = SILO_CONFIG.getSilos();

        uint256 userBorrowedAmount = SILO_LENS.debtBalanceOfUnderlying(ISilo(silo0), EXAMPLE_USER);

        assertEq(userBorrowedAmount, 10400188355193975, "User have to repay ~0.0104 wstETH including interest");
        assertEq(userBorrowedAmount, ISilo(silo0).maxRepay(EXAMPLE_USER), "Same way to read the debt amount");
    }

    // Get user's loan-to-value ratio. For example, 0.5 * 10**18 LTV is for a position with 10$ collateral and
    // 5$ borrowed assets.
    function test_getMyLTV() public {
        (address silo0,) = SILO_CONFIG.getSilos();
        uint256 userLTV = SILO_LENS.getLtv(ISilo(silo0), EXAMPLE_USER);

        assertEq(userLTV, 0);
    }
    function test_getMarketLT() public {}
    function test_estimateMyLiquidationTime() public {}
    function test_getMarketLiquidity() public {}
    function test_getMarketParams() public {}
}
