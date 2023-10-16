// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";

import {IERC3156FlashLender} from "./IERC3156FlashLender.sol";
import {ISiloConfig} from "./ISiloConfig.sol";
import {ISiloFactory} from "./ISiloFactory.sol";
import {ILeverageBorrower} from "./ILeverageBorrower.sol";
import {ISiloLiquidation} from "./ISiloLiquidation.sol";

// solhint-disable ordering
interface ISilo is IERC4626, IERC3156FlashLender, ISiloLiquidation {
    /// @dev Interest accrual happens on each deposit/withdraw/borrow/repay. View methods work on storage that might be
    ///      outdate. Some calculations require accrued interest to return current state of Silo. This struct is used
    ///      to make a decision inside functions if interest should be accrued in memory to work on updated values.
    enum AccrueInterestInMemory {
        No,
        Yes
    }

    /// @dev Silo has two separate oracles for solvency and maxLtv calculations. MaxLtv oracle is optional. Solvency
    ///      oracle can also be optional if asset is used as denominator in Silo config. For example, in ETH/USDC Silo
    ///      one could setup only solvency oracle for ETH that returns price in USDC. Then USDC does not need an oracle
    ///      because it's used as denominator for ETH and it's "price" can be assume as 1.
    enum OracleType {
        Solvency,
        MaxLtv
    }

    /// @dev There are 3 types of accounting in the system: for non-borrowable collateral deposit called "protected",
    ///      for borrowable collateral deposit called "collateral" and for borrowed tokens called "debt". System does
    ///      identical calculations for each type of accounting but it uses different data. To avoid code duplication
    ///      this enum is used to decide which data should be read.
    enum AssetType {
        Protected, // default
        Collateral,
        Debt
        // if you add new, make sure you adjust all places with revert WrongAssetType()
    }

    /// @dev this struct is used for all types of assets: collateral, protected and debt
    /// @param assets based on type:
    /// - PROTECTED COLLATERAL: Amount of asset token that has been deposited to Silo that can be ONLY used
    /// as collateral. These deposits do NOT earn interest and CANNOT be borrowed.
    /// - COLLATERAL: Amount of asset token that has been deposited to Silo plus interest earned by depositors.
    /// It also includes token amount that has been borrowed.
    /// - DEBT: Amount of asset token that has been borrowed plus accrued interest.
    struct Assets {
        uint256 assets;
    }

    /// @dev Storage struct that holds all required data for a single token market
    /// @param daoAndDeployerFees Current amount of fees accrued by DAO and Deployer
    /// @param interestRateTimestamp timestamp of the last interest accrual
    /// @param assets map of assets
    struct SiloData {
        uint192 daoAndDeployerFees;
        uint64 interestRateTimestamp;
    }

    struct UtilizationData {
        /// @dev COLLATERAL: Amount of asset token that has been deposited to Silo plus interest earned by depositors.
        /// It also includes token amount that has been borrowed.
        uint128 collateralAssets;
        /// @dev DEBT: Amount of asset token that has been borrowed plus accrued interest.
        uint128 debtAssets;
        /// @dev timestamp of the last interest accrual
        uint64 interestRateTimestamp;
    }

    /// @notice Emitted on protected deposit
    /// @param sender wallet address that deposited asset
    /// @param owner wallet address that received shares in Silo
    /// @param assets amount of asset that was deposited
    /// @param shares amount of shares that was minted
    event DepositProtected(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

    /// @notice Emitted on protected withdraw
    /// @param sender wallet address that sent transaction
    /// @param receiver wallet address that received asset
    /// @param owner wallet address that owned asset
    /// @param assets amount of asset that was withdrew
    /// @param shares amount of shares that was burn
    event WithdrawProtected(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    /// @notice Emitted on borrow
    /// @param sender wallet address that sent transaction
    /// @param receiver wallet address that received asset
    /// @param owner wallet address that owes assets
    /// @param assets amount of asset that was borrowed
    /// @param shares amount of shares that was minted
    event Borrow(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    /// @notice Emitted on repayment
    /// @param sender wallet address that repaid asset
    /// @param owner wallet address that owed asset
    /// @param assets amount of asset that was repaid
    /// @param shares amount of shares that was burn
    event Repay(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

    /// @notice Emitted on leverage
    event Leverage();

    error Unsupported();
    error DepositNotPossible();
    error NothingToWithdraw();
    error NotEnoughLiquidity();
    error NotSolvent();
    error BorrowNotPossible();
    error WrongToken();
    error NothingToPay();
    error FlashloanFailed();
    error LeverageFailed();
    error AboveMaxLtv();
    error WrongAssetType();
    error ZeroAssets();
    error ZeroShares();
    error Overflow();

    function initialize(ISiloConfig _config, address _modelConfigAddress) external;

    function config() external view returns (ISiloConfig siloConfig);
    function siloId() external view returns (uint256 siloId);
    function siloData() external view returns (uint192 daoAndDeployerFees, uint64 interestRateTimestamp);
    function utilizationData() external view returns (UtilizationData memory utilizationData);
    function getLiquidity() external view returns (uint256 liquidity);

    function isSolvent(address _borrower) external view returns (bool);
    function depositPossible(address _depositor) external view returns (bool);
    function borrowPossible(address _borrower) external view returns (bool);
    function getMaxLtv() external view returns (uint256 maxLtv);
    function getLt() external view returns (uint256 lt);
    function getProtectedAssets() external view returns (uint256 totalProtectedAssets);
    function getCollateralAssets() external view returns (uint256 totalCollateralAssets);
    function getDebtAssets() external view returns (uint256 totalDebtAssets);
    function getCollateralAndProtectedAssets()
        external
        view
        returns (uint256 totalCollateralAssets, uint256 totalProtectedAssets);

    function getFeesAndFeeReceivers()
        external
        view
        returns (address daoFeeReceiver, address deployerFeeReceiver, uint256 daoFeeInBp, uint256 deployerFeeInBp);

    function convertToShares(uint256 _assets, AssetType _assetType) external view returns (uint256 shares);
    function convertToAssets(uint256 _shares, AssetType _assetType) external view returns (uint256 assets);

    function maxDeposit(address _receiver, AssetType _assetType) external view returns (uint256 maxAssets);
    function previewDeposit(uint256 _assets, AssetType _assetType) external view returns (uint256 shares);
    function deposit(uint256 _assets, address _receiver, AssetType _assetType) external returns (uint256 shares);

    function maxMint(address _receiver, AssetType _assetType) external view returns (uint256 maxShares);
    function previewMint(uint256 _shares, AssetType _assetType) external view returns (uint256 assets);
    function mint(uint256 _shares, address _receiver, AssetType _assetType) external returns (uint256 assets);

    function maxWithdraw(address _owner, AssetType _assetType) external view returns (uint256 maxAssets);
    function previewWithdraw(uint256 _assets, AssetType _assetType) external view returns (uint256 shares);
    function withdraw(uint256 _assets, address _receiver, address _owner, AssetType _assetType)
        external
        returns (uint256 shares);

    function maxRedeem(address _owner, AssetType _assetType) external view returns (uint256 maxShares);
    function previewRedeem(uint256 _shares, AssetType _assetType) external view returns (uint256 assets);
    function redeem(uint256 _shares, address _receiver, address _owner, AssetType _assetType)
        external
        returns (uint256 assets);

    function transitionCollateral(uint256 _shares, address _owner, AssetType _withdrawType)
        external
        returns (uint256 assets);

    function maxBorrow(address _borrower) external view returns (uint256 maxAssets);
    function previewBorrow(uint256 _assets) external view returns (uint256 shares);
    function borrow(uint256 _assets, address _receiver, address _borrower) external returns (uint256 shares);

    function maxBorrowShares(address _borrower) external view returns (uint256 maxShares);
    function previewBorrowShares(uint256 _shares) external view returns (uint256 assets);
    function borrowShares(uint256 _shares, address _receiver, address _borrower) external returns (uint256 assets);

    function maxRepay(address _borrower) external view returns (uint256 assets);
    function previewRepay(uint256 _assets) external view returns (uint256 shares);
    function repay(uint256 _assets, address _borrower) external returns (uint256 shares);

    function maxRepayShares(address _borrower) external view returns (uint256 shares);
    function previewRepayShares(uint256 _shares) external view returns (uint256 assets);
    function repayShares(uint256 _shares, address _borrower) external returns (uint256 assets);

    function leverage(uint256 _assets, ILeverageBorrower _receiver, address _borrower, bytes calldata _data)
        external
        returns (uint256 shares);

    function accrueInterest() external returns (uint256 accruedInterest);

    function withdrawFees() external;
}
