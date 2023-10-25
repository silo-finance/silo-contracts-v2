// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IERC4626, IERC20, IERC20Metadata} from "openzeppelin-contracts/interfaces/IERC4626.sol";

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
        uint256 collateralAssets;
        /// @dev DEBT: Amount of asset token that has been borrowed plus accrued interest.
        uint256 debtAssets;
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

    /// @notice Initialize Silo
    /// @param _siloConfig address of ISiloConfig with full config for this Silo
    /// @param _modelConfigAddress address of a config contract used by IRM
    function initialize(ISiloConfig _siloConfig, address _modelConfigAddress) external;

    /// @notice Fetches the silo configuration contract
    /// @return siloConfig Address of the configuration contract associated with the silo
    function config() external view returns (ISiloConfig siloConfig);

    /// @notice Fetches the data related to the silo
    /// @return daoAndDeployerFees Current amount of fees accrued by DAO and Deployer
    /// @return interestRateTimestamp Timestamp of the last interest accrual
    function siloData() external view returns (uint192 daoAndDeployerFees, uint64 interestRateTimestamp);

    /// @notice Fetches details about the contract's version, the associated factory, and the siloId
    /// @return version The version string of the contract
    /// @return factory The associated factory of the silo
    /// @return siloId The unique identifier for the silo
    function getInfo()
        external
        view
        returns (string memory version, ISiloFactory factory, uint256 siloId);

    /// @notice Fetches the utilization data of the silo used by IRM
    function utilizationData() external view returns (UtilizationData memory utilizationData);

    /// @notice Fetches the available liquidity in the silo
    /// @return liquidity The amount of available liquidity
    function getLiquidity() external view returns (uint256 liquidity);

    /// @notice Determines if a borrower is solvent
    /// @param _borrower Address of the borrower to check for solvency
    /// @return True if the borrower is solvent, otherwise false
    function isSolvent(address _borrower) external view returns (bool);

    /// @notice Checks if a deposit is possible for a given depositor
    /// @param _depositor Address of the depositor to check for deposit possibility
    /// @return True if deposit is possible for the depositor, otherwise false
    function depositPossible(address _depositor) external view returns (bool);

    /// @notice Checks if borrowing is possible for a given borrower
    /// @param _borrower Address of the borrower to check for borrowing possibility
    /// @return True if borrowing is possible for the borrower, otherwise false
    function borrowPossible(address _borrower) external view returns (bool);

    /// @notice Retrieves the maximum loan-to-value (LTV) ratio after normalization
    /// @dev The returned value is normalized from 18 decimals to 4 decimals precision
    /// @return maxLtvInBp The normalized maximum LTV ratio configured for the silo in basis points
    function getMaxLtv() external view returns (uint256 maxLtvInBp);

    /// @notice Retrieves the LT value after normalization
    /// @dev The returned value is normalized from 18 decimals to 4 decimals precision
    /// @return ltInBp The normalized LT value in basis points
    function getLt() external view returns (uint256 ltInBp);

    /// @notice Retrieves the loan-to-value (LTV) for a specific borrower after normalization
    /// @dev The returned LTV is normalized from 18 decimals to 4 decimals precision
    /// @param _borrower Address of the borrower
    /// @return ltvInBp The normalized LTV for the borrower in basis points
    function getLtv(address _borrower) external view returns (uint256 ltvInBp);

    /// @notice Retrieves the total amount of protected (non-borrowable) collateral assets
    /// @return totalProtectedAssets The total amount of assets of type 'Protected'
    function getProtectedAssets() external view returns (uint256 totalProtectedAssets);

    /// @notice Retrieves the total amount of collateral (borrowable) assets
    /// @return totalCollateralAssets The total amount of assets of type 'Collateral'
    function getCollateralAssets() external view returns (uint256 totalCollateralAssets);

    /// @notice Retrieves the total amount of debt assets
    /// @return totalDebtAssets The total amount of assets of type 'Debt'
    function getDebtAssets() external view returns (uint256 totalDebtAssets);

    /// @notice Retrieves the total amounts of collateral and protected (non-borrowable) assets
    /// @return totalCollateralAssets The total amount of assets of type 'Collateral'
    /// @return totalProtectedAssets The total amount of protected (non-borrowable) assets
    function getCollateralAndProtectedAssets()
        external
        view
        returns (uint256 totalCollateralAssets, uint256 totalProtectedAssets);

    /// @notice Retrieves the fee details in basis points and the addresses of the DAO and deployer fee receivers
    /// @return daoFeeReceiver The address of the DAO fee receiver
    /// @return deployerFeeReceiver The address of the deployer fee receiver
    /// @return daoFeeInBp The total fee for the DAO in basis points
    /// @return deployerFeeInBp The total fee for the deployer in basis points
    function getFeesAndFeeReceivers()
        external
        view
        returns (address daoFeeReceiver, address deployerFeeReceiver, uint256 daoFeeInBp, uint256 deployerFeeInBp);

    /// @notice Implements IERC4626.convertToShares for each asset type
    function convertToShares(uint256 _assets, AssetType _assetType) external view returns (uint256 shares);

    /// @notice Implements IERC4626.convertToAssets for each asset type
    function convertToAssets(uint256 _shares, AssetType _assetType) external view returns (uint256 assets);

    /// @notice Implements IERC4626.maxDeposit for protected (non-borrowable) collateral and collateral
    /// @dev _assetType is ignored because maxDeposit is the same for both asset types
    function maxDeposit(address _receiver, AssetType _assetType) external view returns (uint256 maxAssets);

    /// @notice Implements IERC4626.previewDeposit for protected (non-borrowable) collateral and collateral
    /// @dev Reverts for debt asset type
    function previewDeposit(uint256 _assets, AssetType _assetType) external view returns (uint256 shares);

    /// @notice Implements IERC4626.deposit for protected (non-borrowable) collateral and collateral
    /// @dev Reverts for debt asset type
    function deposit(uint256 _assets, address _receiver, AssetType _assetType) external returns (uint256 shares);

    /// @notice Implements IERC4626.maxMint for protected (non-borrowable) collateral and collateral
    /// @dev _assetType is ignored because maxDeposit is the same for both asset types
    function maxMint(address _receiver, AssetType _assetType) external view returns (uint256 maxShares);

    /// @notice Implements IERC4626.previewMint for protected (non-borrowable) collateral and collateral
    /// @dev Reverts for debt asset type
    function previewMint(uint256 _shares, AssetType _assetType) external view returns (uint256 assets);

    /// @notice Implements IERC4626.mint for protected (non-borrowable) collateral and collateral
    /// @dev Reverts for debt asset type
    function mint(uint256 _shares, address _receiver, AssetType _assetType) external returns (uint256 assets);

    /// @notice Implements IERC4626.maxWithdraw for protected (non-borrowable) collateral and collateral
    /// @dev Reverts for debt asset type
    function maxWithdraw(address _owner, AssetType _assetType) external view returns (uint256 maxAssets);

    /// @notice Implements IERC4626.previewWithdraw for protected (non-borrowable) collateral and collateral
    /// @dev Reverts for debt asset type
    function previewWithdraw(uint256 _assets, AssetType _assetType) external view returns (uint256 shares);

    /// @notice Implements IERC4626.withdraw for protected (non-borrowable) collateral and collateral
    /// @dev Reverts for debt asset type
    function withdraw(uint256 _assets, address _receiver, address _owner, AssetType _assetType)
        external
        returns (uint256 shares);

    /// @notice Implements IERC4626.maxRedeem for protected (non-borrowable) collateral and collateral
    /// @dev Reverts for debt asset type
    function maxRedeem(address _owner, AssetType _assetType) external view returns (uint256 maxShares);

    /// @notice Implements IERC4626.previewRedeem for protected (non-borrowable) collateral and collateral
    /// @dev Reverts for debt asset type
    function previewRedeem(uint256 _shares, AssetType _assetType) external view returns (uint256 assets);

    /// @notice Implements IERC4626.redeem for protected (non-borrowable) collateral and collateral
    /// @dev Reverts for debt asset type
    function redeem(uint256 _shares, address _receiver, address _owner, AssetType _assetType)
        external
        returns (uint256 assets);

    /// @notice Transitions assets between borrowable (collateral) and non-borrowable (protected) states
    /// @dev This function allows assets to move between collateral and protected (non-borrowable) states without
    /// leaving the protocol
    /// @param _shares Amount of shares to be transitioned
    /// @param _owner Owner of the assets being transitioned
    /// @param _withdrawType Specifies if the transition is from collateral or protected assets
    /// @return assets Amount of assets transitioned
    function transitionCollateral(uint256 _shares, address _owner, AssetType _withdrawType)
        external
        returns (uint256 assets);

    /// @notice Calculates the maximum amount of assets that can be borrowed by the given address
    /// @param _borrower Address of the potential borrower
    /// @return maxAssets Maximum amount of assets that the borrower can borrow
    function maxBorrow(address _borrower) external view returns (uint256 maxAssets);

    /// @notice Previews the amount of shares equivalent to the given asset amount for borrowing
    /// @param _assets Amount of assets to preview the equivalent shares for
    /// @return shares Amount of shares equivalent to the provided asset amount
    function previewBorrow(uint256 _assets) external view returns (uint256 shares);

    /// @notice Allows an address to borrow a specified amount of assets
    /// @param _assets Amount of assets to borrow
    /// @param _receiver Address receiving the borrowed assets
    /// @param _borrower Address responsible for the borrowed assets
    /// @return shares Amount of shares equivalent to the borrowed assets
    function borrow(uint256 _assets, address _receiver, address _borrower) external returns (uint256 shares);

    /// @notice Calculates the maximum amount of shares that can be borrowed by the given address
    /// @param _borrower Address of the potential borrower
    /// @return maxShares Maximum number of shares that the borrower can borrow
    function maxBorrowShares(address _borrower) external view returns (uint256 maxShares);

    /// @notice Previews the amount of assets equivalent to the given share amount for borrowing
    /// @param _shares Amount of shares to preview the equivalent assets for
    /// @return assets Amount of assets equivalent to the provided share amount
    function previewBorrowShares(uint256 _shares) external view returns (uint256 assets);

    /// @notice Allows a user to borrow assets based on the provided share amount
    /// @param _shares Amount of shares to borrow against
    /// @param _receiver Address to receive the borrowed assets
    /// @param _borrower Address responsible for the borrowed assets
    /// @return assets Amount of assets borrowed
    function borrowShares(uint256 _shares, address _receiver, address _borrower) external returns (uint256 assets);

    /// @notice Calculates the maximum amount an address can repay based on their debt shares
    /// @param _borrower Address of the borrower
    /// @return assets Maximum amount of assets the borrower can repay
    function maxRepay(address _borrower) external view returns (uint256 assets);

    /// @notice Provides an estimation of the number of shares equivalent to a given asset amount for repayment
    /// @param _assets Amount of assets to be repaid
    /// @return shares Estimated number of shares equivalent to the provided asset amount
    function previewRepay(uint256 _assets) external view returns (uint256 shares);

    /// @notice Repays a given asset amount and returns the equivalent number of shares
    /// @param _assets Amount of assets to be repaid
    /// @param _borrower Address of the borrower whose debt is being repaid
    /// @return shares The equivalent number of shares for the provided asset amount
    function repay(uint256 _assets, address _borrower) external returns (uint256 shares);

    /// @notice Calculates the maximum number of shares that can be repaid for a given borrower
    /// @param _borrower Address of the borrower
    /// @return shares The maximum number of shares that can be repaid for the borrower
    function maxRepayShares(address _borrower) external view returns (uint256 shares);

    /// @notice Provides a preview of the equivalent assets for a given number of shares to repay
    /// @param _shares Number of shares to preview repayment for
    /// @return assets Equivalent assets for the provided shares
    function previewRepayShares(uint256 _shares) external view returns (uint256 assets);

    /// @notice Allows a user to repay a loan using shares instead of assets
    /// @param _shares The number of shares the borrower wants to repay with
    /// @param _borrower The address of the borrower for whom to repay the loan
    /// @return assets The equivalent assets amount for the provided shares
    function repayShares(uint256 _shares, address _borrower) external returns (uint256 assets);

    /// @notice Allows a user to leverage their assets to borrow more, given the collateralization ratio constraints
    /// @dev This function's design follows the flash loan pattern and assumes that the user will deposit the proper
    /// amount of collateral by the end of the transaction
    /// @param _assets The number of assets the borrower wants to borrow
    /// @param _receiver The borrower contract that will receive the borrowed assets
    /// @param _borrower The address of the borrower leveraging the assets
    /// @param _data Arbitrary bytes data that might be needed for additional logic in the `_receiver` callback
    /// @return shares The number of shares representing the leveraged borrowed amount
    function leverage(uint256 _assets, ILeverageBorrower _receiver, address _borrower, bytes calldata _data)
        external
        returns (uint256 shares);

    /// @notice Accrues interest for the asset and returns the accrued interest amount
    /// @return accruedInterest The total interest accrued during this operation
    function accrueInterest() external returns (uint256 accruedInterest);

    /// @notice Withdraws earned fees and distributes them to the DAO and deployer fee receivers
    function withdrawFees() external;
}
