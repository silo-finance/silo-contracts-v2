// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import {ISiloConfig} from "./ISiloConfig.sol";
import {ISiloFactory} from "./ISiloFactory.sol";

interface ISilo {
    // TODO: optimized storage to use uint128 and uncheck math
    /// @dev Storage struct that holds all required data for a single token market
    struct AssetStorage {
        /// @dev PROTECTED COLLATERAL: Amount of asset token that has been deposited to Silo that can be ONLY used
        /// as collateral. These deposits do NOT earn interest and CANNOT be borrowed.
        uint256 protectedAssets;
        /// @dev COLLATERAL: Amount of asset token that has been deposited to Silo plus interest earned by depositors.
        /// It also includes token amount that has been borrowed.
        uint256 collateralAssets;
        /// @dev DEBT: Amount of asset token that has been borrowed plus accrued interest.
        uint256 debtAssets;
        /// @dev Current amount of fees accrued by DAO and Deployer
        uint256 daoAndDeployerFees;
        /// @dev timestamp of the last interest accrual
        uint64 interestRateTimestamp;
    }

    /// @notice Emitted on deposit
    /// @param sender wallet address that deposited asset
    /// @param owner wallet address that received shares in Silo
    /// @param assets amount of asset that was deposited
    /// @param shares amount of shares that was minted
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

    /// @notice Emitted on protected deposit
    /// @param sender wallet address that deposited asset
    /// @param owner wallet address that received shares in Silo
    /// @param assets amount of asset that was deposited
    /// @param shares amount of shares that was minted
    event DepositProtected(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

    /// @notice Emitted on withdraw
    /// @param sender wallet address that sent transaction
    /// @param receiver wallet address that received asset
    /// @param owner wallet address that owned asset
    /// @param assets amount of asset that was withdrew
    /// @param shares amount of shares that was burn
    event Withdraw(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

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

    function initialize(ISiloConfig _config) external;

    function config() external view returns (ISiloConfig);
    function siloId() external view returns (uint256);
    function assetStorage(address _token) external view returns (uint256, uint256, uint256, uint256, uint64);

    function isSolvent(address _borrower) external returns (bool); // solhint-disable-line ordering
    function depositPossible(address _depositor) external view returns (bool);
    function borrowPossible(address _borrower) external view returns (bool);
    function getMaxLtv() external view returns (uint256);
    function getLt() external view returns (uint256);
    function getProtectedAssets() external view returns (uint256);
    function getCollateralAssets() external view returns (uint256);
    function getDebtAssets() external view returns (uint256);

    // ERC4626

    function asset() external view returns (address assetTokenAddress);
    function totalAssets() external view returns (uint256 totalManagedAssets);

    function convertToShares(uint256 _assets) external view returns (uint256 shares);
    function convertToAssets(uint256 _shares) external view returns (uint256 assets);

    function maxDeposit(address _receiver) external view returns (uint256 maxAssets);
    function previewDeposit(uint256 _assets) external view returns (uint256 shares);
    function deposit(uint256 _assets, address _receiver) external returns (uint256 shares);

    function maxMint(address _receiver) external view returns (uint256 maxShares);
    function previewMint(uint256 _shares) external view returns (uint256 assets);
    function mint(uint256 _shares, address _receiver) external returns (uint256 assets);

    function maxWithdraw(address _owner) external view returns (uint256 maxAssets);
    function previewWithdraw(uint256 _assets) external view returns (uint256 shares);
    function withdraw(uint256 _assets, address _receiver, address _owner) external returns (uint256 shares);

    function maxRedeem(address _owner) external view returns (uint256 maxShares);
    function previewRedeem(uint256 _shares) external view returns (uint256 assets);
    function redeem(uint256 _shares, address _receiver, address _owner) external returns (uint256 assets);

    // Protected

    function convertToShares(uint256 _assets, bool _isProtected) external view returns (uint256 shares);
    function convertToAssets(uint256 _shares, bool _isProtected) external view returns (uint256 assets);

    function maxDeposit(address _receiver, bool _isProtected) external view returns (uint256 maxAssets);
    function previewDeposit(uint256 _assets, bool _isProtected) external view returns (uint256 shares);
    function deposit(uint256 _assets, address _receiver, bool _isProtected) external returns (uint256 shares);

    function maxMint(address _receiver, bool _isProtected) external view returns (uint256 maxShares);
    function previewMint(uint256 _shares, bool _isProtected) external view returns (uint256 assets);
    function mint(uint256 _shares, address _receiver, bool _isProtected) external returns (uint256 assets);

    function maxWithdraw(address _owner, bool _isProtected) external view returns (uint256 maxAssets);
    function previewWithdraw(uint256 _assets, bool _isProtected) external view returns (uint256 shares);
    function withdraw(uint256 _assets, address _receiver, address _owner, bool _isProtected)
        external
        returns (uint256 shares);

    function maxRedeem(address _owner, bool _isProtected) external view returns (uint256 maxShares);
    function previewRedeem(uint256 _shares, bool _isProtected) external view returns (uint256 assets);
    function redeem(uint256 _shares, address _receiver, address _owner, bool _isProtected)
        external
        returns (uint256 assets);

    function transitionToProtected(uint256 _shares, address _owner) external returns (uint256 assets);
    function transitionFromProtected(uint256 _shares, address _owner) external returns (uint256 shares);

    // Lending

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

    // TODO: https://eips.ethereum.org/EIPS/eip-3156
    function flashloan(uint256 _assets, address _borrower, address _receiver, bytes memory _flashloanReceiverData)
        external
        returns (uint256 shares);
    function leverage() external;
    // TODO: allow selfliquidate
    function liquidate(address _borrower) external;
    function accrueInterest() external returns (uint256 accruedInterest);

    function withdrawFees() external;
}
