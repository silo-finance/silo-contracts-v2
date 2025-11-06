// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {SiloVault} from "../../../contracts/SiloVault.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IIncentivesClaimingLogic} from "../../../contracts/interfaces/IIncentivesClaimingLogic.sol";
import {SiloIncentivesControllerCLFactory} from
    "../../../contracts/incentives/claiming-logics/SiloIncentivesControllerCLFactory.sol";
import {SiloVaultsContracts, SiloVaultsDeployments} from "silo-vaults/common/SiloVaultsContracts.sol";
import {IVaultIncentivesModule} from "../../../contracts/interfaces/IVaultIncentivesModule.sol";

import {BorrowFromSilo} from "silo-vaults/contracts/utils/BorrowFromSilo.sol";

/*
FOUNDRY_PROFILE=vaults_tests forge test --ffi --mt test_vault_borrow -vvv
*/
contract VaultBorrow is Test {
    SiloVault internal constant VAULT = SiloVault(0x2BA39e5388aC6C702Cb29AEA78d52aa66832f1ee);
    ISilo internal constant SILO = ISilo(0xf0543D476e7906374863091034fe679a7bE8Ee20);
    IERC20Metadata internal SILO_ASSET;

    IVaultIncentivesModule internal incentivesModule;

    IERC20 internal wAvax = IERC20(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_ARBITRUM"), 397368393);
        console2.log("block number", block.number);

        incentivesModule = VAULT.INCENTIVES_MODULE();
        SILO_ASSET = IERC20Metadata(SILO.asset());
    }

    /*
    FOUNDRY_PROFILE=vaults_tests forge test --ffi --mt test_vault_borrow -vvv
    */
    function test_vault_borrow() public {
        uint256 assetDecimals = SILO_ASSET.decimals();
        console2.log("silo asset symbol", SILO_ASSET.symbol());
        console2.log("asset decimals", assetDecimals);
        assertEq(SILO_ASSET.balanceOf(address(VAULT)), 0, "silo asset should be 0");
        emit log_named_decimal_uint("silo asset VAULT balance", SILO_ASSET.balanceOf(address(VAULT)), assetDecimals);
        console2.log("VAULT assets", VAULT.asset());
        console2.log("VAULT assets symbol", IERC20Metadata(VAULT.asset()).symbol());
        console2.log("VAULT timelock", VAULT.timelock());

        // we need to have access to owner of the incentivesModule
        address incentivesModuleOwner = Ownable(address(incentivesModule)).owner();
        console2.log("vault incentives module", address(incentivesModule));
        console2.log("incentives module owner", incentivesModuleOwner);

        uint256 assetBalanceBefore = SILO_ASSET.balanceOf(address(VAULT));
        console2.log("silo asset balance before", assetBalanceBefore);

        uint256 maxBorrow = SILO.maxBorrow(address(VAULT));
        console2.log("VAULT maxBorrow", maxBorrow);
        console2.log("SILO liquidity", SILO.getLiquidity());


        BorrowFromSilo newLogic = new BorrowFromSilo();
        // we need to call `submitIncentivesClaimingLogic` from safe
        vm.prank(incentivesModuleOwner);
        incentivesModule.submitIncentivesClaimingLogic(VAULT, newLogic);

        // _qaVaultOperations();
        _printLogics();

        // we need to wait for the timelock to pass, because we not using trusted factory
        vm.warp(block.timestamp + VAULT.timelock());

        // anyone can accept the logic, so we can call it + claim rewards
        incentivesModule.acceptIncentivesClaimingLogic(VAULT, newLogic);

        // _qaVaultOperations();

        // THIS WILL BORROW TOKENS
        VAULT.claimRewards();

        assertGt(SILO_ASSET.balanceOf(address(VAULT)), maxBorrow, "silo asset should be borrowed");

return;
        uint256 assetBalanceAfter = SILO_ASSET.balanceOf(address(VAULT));
        emit log_named_decimal_uint("wAvax balance after", assetBalanceAfter, assetDecimals);

        _qaVaultOperations();

        // then incentive module owner can remove the logic
        vm.prank(incentivesModuleOwner);
        incentivesModule.removeIncentivesClaimingLogic(VAULT, newLogic);

        assertEq(_printLogics(), 0, "no logics should be left");
        _qaVaultOperations();
    }

    function _qaVaultOperations() internal {
        console2.log("\t ------- QA vault operations -------");
        VAULT.claimRewards(); // always work

        address usdtWhale = 0x5fA70a4D7635618afCE319e0F09c67a2Ec661c8b;
        IERC20 asset = IERC20Metadata(VAULT.asset());

        vm.prank(usdtWhale);
        asset.transfer(address(this), 100e6);

        asset.approve(address(VAULT), 100e6);
        VAULT.deposit(100e6, address(this));

        // NOTICE: we can not withdraw total amount of assets for unknown reason (reason not checked)
        VAULT.withdraw(VAULT.maxWithdraw(address(this)), address(this), address(this));

        VAULT.claimRewards(); // always work
    }

    function _printLogics() internal view returns (uint256 totalLogics) {
        address[] memory logics = incentivesModule.getAllIncentivesClaimingLogics();
        totalLogics = logics.length;
        console2.log("--------------------------------\nlogics length", totalLogics);

        for (uint256 i = 0; i < totalLogics; i++) {
            console2.log("logic", logics[i]);
        }
    }
}
