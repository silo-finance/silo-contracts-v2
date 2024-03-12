pragma solidity ^0.8.0;

import {Silo, ISilo} from "silo-core/contracts/Silo.sol";
import {PartialLiquidation} from "silo-core/contracts/liquidation/PartialLiquidation.sol";
import {ISiloConfig} from "silo-core/contracts/SiloConfig.sol";
import {TestERC20Token} from "properties/ERC4626/util/TestERC20Token.sol";
import {PropertiesAsserts} from "properties/util/PropertiesHelper.sol";

/// @notice This contract has two purposes:
///  1. Act as a proxy for performing vault deposits/withdraws (since we don't have vm.prank)
///  2. Keep track of how much the account has deposited/withdrawn & raise an error if the account can withdraw/redeem more than it deposited/minted.
/// @dev It's important that other property tests never send tokens/shares to the Actor contract address, or else the accounting will break. This restriction is enforced in restrictAddressToThirdParties()
///      If support is added for "harvesting" a vault during property tests, the accounting logic here needs to be updated to reflect cases where an actor can withdraw more than they deposited.
contract Actor is PropertiesAsserts {
    TestERC20Token token0;
    TestERC20Token token1;
    Silo vault0;
    Silo vault1;
    PartialLiquidation liquidationModule;

    mapping(address => uint256) public tokensDepositedCollateral;
    mapping(address => uint256) public tokensDepositedProtected;
    mapping(address => uint256) public tokensBorrowed;
    mapping(address => uint256) public protectedMinted;
    mapping(address => uint256) public collateralMinted;
    mapping(address => uint256) public debtMinted;
    constructor(Silo _vault0, Silo _vault1) {
        vault0 = _vault0;
        vault1 = _vault1;
        token0 = TestERC20Token(address(_vault0.asset()));
        token1 = TestERC20Token(address(_vault1.asset()));
        liquidationModule = PartialLiquidation(_vault0.config().getConfig(address(_vault0)).liquidationModule);
    }

    function accountForOpenedPosition(ISilo.AssetType assetType, bool vaultZero, uint256 _tokensDeposited, uint256 _sharesMinted) internal {
        address vault = vaultZero ? address(vault0) : address(vault1);

        if (assetType == ISilo.AssetType.Collateral) {
            tokensDepositedCollateral[vault] += _tokensDeposited;
            collateralMinted[vault] += _sharesMinted;
        } else if (assetType == ISilo.AssetType.Protected) {
            tokensDepositedProtected[vault] += _tokensDeposited;
            protectedMinted[vault] += _sharesMinted;
        } else {
            tokensBorrowed[vault] += _tokensDeposited;
            debtMinted[vault] += _sharesMinted;
        }
    }

    function accountForClosedPosition(
        ISilo.AssetType /* assetType */,
        bool vaultZero,
        uint256 /* _tokensReceived */,
        uint256 /* _sharesBurned */
    ) internal pure {
        // address vault = vaultZero ? address(vault0) : address(vault1);

        // note: The below code can lead to false positives since it does not account for interest.
        // In order to properly check these properties it needs to be modified so the accounting is correct.

/*         if (assetType == ISilo.AssetType.Collateral) {
            assertLte(_sharesBurned, collateralMinted[vault],  "Actor has burned more shares than they ever minted. Implies a rounding or accounting error");
            assertLte(_tokensReceived, tokensDepositedCollateral[vault],  "Actor has withdrawn more tokens than they ever deposited. Implies a rounding or accounting error");
            tokensDepositedCollateral[vault] -= _tokensReceived;
            collateralMinted[vault] -= _sharesBurned;
        } else if (assetType == ISilo.AssetType.Protected) {
            assertLte(_sharesBurned, protectedMinted[vault],  "Actor has burned more shares than they ever minted. Implies a rounding or accounting error");
            assertLte(_tokensReceived, tokensDepositedProtected[vault],  "Actor has withdrawn more tokens than they ever deposited. Implies a rounding or accounting error");
            tokensDepositedProtected[vault] -= _tokensReceived;
            protectedMinted[vault] -= _sharesBurned;
        } else {
            assertLte(_sharesBurned, debtMinted[vault],  "Actor has burned more shares than they ever minted. Implies a rounding or accounting error");
            assertLte(_tokensReceived, tokensBorrowed[vault],  "Actor has withdrawn more tokens than they ever deposited. Implies a rounding or accounting error");
            tokensBorrowed[vault] -= _tokensReceived;
            debtMinted[vault] -= _sharesBurned;
        } */
    }

    function fund(bool vaultZero, uint256 amount) internal {
        TestERC20Token token = vaultZero ? token0 : token1;

        token.mint(address(this), amount);
    }

    function approveFunds(bool vaultZero, uint256 amount, address vault) internal {
        TestERC20Token token = vaultZero ? token0 : token1;

        token.approve(vault, amount);
    }

    function prepareForDeposit(bool vaultZero, uint256 amount) internal returns (Silo vault){
        vault = vaultZero ? vault0 : vault1;
        fund(vaultZero, amount);
        approveFunds(vaultZero, amount, address(vault));
    }

    function prepareForDepositShares(bool vaultZero, uint256 shares, ISilo.AssetType assetType) internal returns (Silo vault, uint256 amount) {
        vault = vaultZero ? vault0 : vault1;
        amount = vault.previewMint(shares, assetType);

        prepareForDeposit(vaultZero, amount);
    }

    function prepareForRepayShares(bool vaultZero, uint256 shares) internal returns (Silo vault, uint256 amount) {
        vault = vaultZero ? vault0 : vault1;
        amount = vault.previewRepayShares(shares);
        
        approveFunds(vaultZero, amount, address(vault));
    }

    function deposit(bool vaultZero, uint256 assets) public returns (uint256 shares) {
        Silo vault = prepareForDeposit(vaultZero, assets);

        shares = vault.deposit(assets, address(this));
        accountForOpenedPosition(ISilo.AssetType.Collateral, vaultZero, assets, shares);
    }

    function depositAssetType(bool vaultZero, uint256 assets, ISilo.AssetType assetType) public returns (uint256 shares) {
        Silo vault = prepareForDeposit(vaultZero, assets);

        shares = vault.deposit(assets, address(this), assetType);
        accountForOpenedPosition(assetType, vaultZero, assets, shares);
    }

    function mint(bool vaultZero, uint256 shares) public returns (uint256 assets) {
        (Silo vault,) = prepareForDepositShares(vaultZero, shares, ISilo.AssetType.Collateral);

        assets = vault.mint(shares, address(this));
        accountForOpenedPosition(ISilo.AssetType.Collateral, vaultZero, assets, shares);
    }

    function mintAssetType(bool vaultZero, uint256 shares, ISilo.AssetType assetType) public returns (uint256 assets) {
        (Silo vault,) = prepareForDepositShares(vaultZero, shares, assetType);

        assets = vault.mint(shares, address(this), assetType);
        accountForOpenedPosition(assetType, vaultZero, assets, shares);
    }

    function withdraw(bool vaultZero, uint256 assets) public returns (uint256 shares) {
        Silo vault = vaultZero ? vault0 : vault1;
        shares = vault.withdraw(assets, address(this), address(this));
        accountForClosedPosition(ISilo.AssetType.Collateral, vaultZero, assets, shares);
    }

    function withdrawAssetType(bool vaultZero, uint256 assets, ISilo.AssetType assetType) public returns (uint256 shares) {
        Silo vault = vaultZero ? vault0 : vault1;
        shares = vault.withdraw(assets, address(this), address(this), assetType);
        accountForClosedPosition(assetType, vaultZero, assets, shares);
    }

    function redeem(bool vaultZero, uint256 shares) public returns (uint256 assets) {
        Silo vault = vaultZero ? vault0 : vault1;
        assets = vault.redeem(shares, address(this), address(this));
        accountForClosedPosition(ISilo.AssetType.Collateral, vaultZero, assets, shares);
    }

    function redeemAssetType(bool vaultZero, uint256 shares, ISilo.AssetType assetType) public returns (uint256 assets) {
        Silo vault = vaultZero ? vault0 : vault1;
        assets = vault.redeem(shares, address(this), address(this), assetType);
        accountForClosedPosition(assetType, vaultZero, assets, shares);
    }

    function borrow(bool vaultZero, uint256 assets) public returns (uint256 shares) {
        Silo vault = vaultZero ? vault0 : vault1;
        shares = vault.borrow(assets, address(this), address(this));
        accountForOpenedPosition(ISilo.AssetType.Debt, vaultZero, assets, shares);
    }

    function borrowShares(bool vaultZero, uint256 shares) public returns (uint256 assets) {
        Silo vault = vaultZero ? vault0 : vault1;
        assets = vault.borrowShares(shares, address(this), address(this));
        accountForOpenedPosition(ISilo.AssetType.Debt, vaultZero, assets, shares);
    }

    function repay(bool vaultZero, uint256 assets) public returns (uint256 shares) {
        Silo vault = vaultZero ? vault0 : vault1;
        approveFunds(vaultZero, assets, address(vault));
        shares = vault.repay(assets, address(this));
        accountForClosedPosition(ISilo.AssetType.Debt, vaultZero, assets, shares);
    }

    function repayShares(bool vaultZero, uint256 shares) public returns (uint256 assets) {
        (Silo vault,) = prepareForRepayShares(vaultZero, shares);
        assets = vault.repayShares(shares, address(this));
        accountForClosedPosition(ISilo.AssetType.Debt, vaultZero, assets, shares);
    }

    function transitionCollateral(bool vaultZero, uint256 shares, ISilo.AssetType withdrawType) public returns (uint256 assets) {
        Silo vault = vaultZero ? vault0 : vault1;
        assets = vault.transitionCollateral(shares, address(this), withdrawType);
        accountForClosedPosition(withdrawType, vaultZero, assets, shares);
        accountForOpenedPosition(withdrawType, vaultZero, assets, shares);
    }

    function liquidationCall(
        bool _vaultZeroWithDebt,
        address borrower,
        uint256 debtToCover,
        bool receiveSToken,
        ISiloConfig config
    ) public {
        Silo vault = prepareForDeposit(_vaultZeroWithDebt, debtToCover);

        (ISiloConfig.ConfigData memory debtConfig, ISiloConfig.ConfigData memory collateralConfig) =
            config.getConfigs(address(vault));

        liquidationModule.liquidationCall(
            address(vault), collateralConfig.token, debtConfig.token, borrower, debtToCover, receiveSToken
        );
    }
}
