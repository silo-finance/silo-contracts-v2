// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {ISiloConfig} from "./ISiloConfig.sol";
import {ISiloFactory} from "./ISiloFactory.sol";

interface ISilo {
    /// @dev Storage struct that holds all required data for a single token market
    struct AssetStorage {
        /// @dev PROTECTED COLLATERAL: Amount of asset token that has been deposited to Silo that can be ONLY used
        /// as collateral. These deposits do NOT earn interest and CANNOT be borrowed.
        uint256 protectedDeposits;
        /// @dev COLLATERAL: Amount of asset token that has been deposited to Silo plus interest earned by depositors.
        /// It also includes token amount that has been borrowed.
        uint256 collateralDeposits;
        /// @dev DEBT: Amount of asset token that has been borrowed plus accrued interest.
        uint256 debtAssets;
        /// @dev timestamp of the last interest accrual
        uint64 interestRateTimestamp;
    }

    function initialize(ISiloConfig _config) external;

    function factory() external view returns (ISiloFactory);
    function config() external view returns (ISiloConfig);
    function siloId() external view returns (uint256);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function assetStorage(address _token) external view returns (uint256, uint256, uint256, uint64);

    function isSolvent(address _borrower) external returns (bool); // solhint-disable-line ordering
    function depositPossible(address _token, address _depositor) external view returns (bool);
    function borrowPossible(address _token, address _borrower) external view returns (bool);
    function getMaxLtv(address _token) external view returns (uint256);
    function getLt(address _token) external view returns (uint256);

    // ERC4626

    function tokens() external view returns (address[2] memory assetTokenAddresses);
    function totalAssets(address _token) external view returns (uint256 totalManagedAssets);

    // Deposits

    function convertToShares(address _token, uint256 _assets) external view returns (uint256 shares);
    function convertToAssets(address _token, uint256 _shares) external view returns (uint256 assets);

    function maxDeposit(address _token, address _receiver) external view returns (uint256 maxAssets);
    function previewDeposit(address _token, uint256 _assets) external view returns (uint256 shares);
    function deposit(address _token, uint256 _assets, address _receiver) external returns (uint256 shares);

    function maxMint(address _token, address _receiver) external view returns (uint256 maxShares);
    function previewMint(address _token, uint256 _shares) external view returns (uint256 assets);
    function mint(address _token, uint256 _shares, address _receiver) external returns (uint256 assets);

    function maxWithdraw(address _token, address _owner) external view returns (uint256 maxAssets);
    function previewWithdraw(address _token, uint256 _assets) external view returns (uint256 shares);
    function withdraw(address _token, uint256 _assets, address _receiver, address _owner)
        external
        returns (uint256 shares);

    function maxRedeem(address _token, address _owner) external view returns (uint256 maxShares);
    function previewRedeem(address _token, uint256 _shares) external view returns (uint256 assets);
    function redeem(address _token, uint256 _shares, address _receiver, address _owner)
        external
        returns (uint256 assets);

    // Protected Deposits

    function convertToShares(address _token, uint256 _assets, bool _isProtected)
        external
        view
        returns (uint256 shares);
    function convertToAssets(address _token, uint256 _shares, bool _isProtected)
        external
        view
        returns (uint256 assets);

    function maxDeposit(address _token, address _receiver, bool _isProtected)
        external
        view
        returns (uint256 maxAssets);
    function previewDeposit(address _token, uint256 _assets, bool _isProtected)
        external
        view
        returns (uint256 shares);
    function deposit(address _token, uint256 _assets, address _receiver, bool _isProtected)
        external
        returns (uint256 shares);

    function maxMint(address _token, address _receiver, bool _isProtected) external view returns (uint256 maxShares);
    function previewMint(address _token, uint256 _shares, bool _isProtected) external view returns (uint256 assets);
    function mint(address _token, uint256 _shares, address _receiver, bool _isProtected)
        external
        returns (uint256 assets);

    function maxWithdraw(address _token, address _owner, bool _isProtected) external view returns (uint256 maxAssets);
    function previewWithdraw(address _token, uint256 _assets, bool _isProtected)
        external
        view
        returns (uint256 shares);
    function withdraw(address _token, uint256 _assets, address _receiver, address _owner, bool _isProtected)
        external
        returns (uint256 shares);

    function maxRedeem(address _token, address _owner, bool _isProtected) external view returns (uint256 maxShares);
    function previewRedeem(address _token, uint256 _shares, bool _isProtected) external view returns (uint256 assets);
    function redeem(address _token, uint256 _shares, address _receiver, address _owner, bool _isProtected)
        external
        returns (uint256 assets);

    function transitionToProtected(address _token, uint256 _shares, address _owner) external returns (uint256 assets);
    function transitionFromProtected(address _token, uint256 _shares, address _owner)
        external
        returns (uint256 shares);

    // Lending

    function maxBorrow(address _token, address _borrower) external view returns (uint256 maxAssets);
    function previewBorrow(address _token, uint256 _assets) external view returns (uint256 shares);
    function borrow(address _token, uint256 _assets, address _receiver, address _borrower)
        external
        returns (uint256 shares);

    function maxBorrowShares(address _token, address _borrower) external view returns (uint256 maxShares);
    function previewBorrowShares(address _token, uint256 _shares) external view returns (uint256 assets);
    function borrowShares(address _token, uint256 _shares, address _receiver, address _borrower)
        external
        returns (uint256 assets);

    function maxRepay(address _token, address _borrower) external view returns (uint256 assets);
    function previewRepay(address _token, uint256 _assets) external view returns (uint256 shares);
    function repay(address _token, uint256 _assets, address _borrower) external returns (uint256 shares);

    function maxRepayShares(address _token, address _borrower) external view returns (uint256 shares);
    function previewRepayShares(address _token, uint256 _shares) external view returns (uint256 assets);
    function repayShares(address _token, uint256 _shares, address repayer, address _borrower)
        external
        returns (uint256 assets);

    // TODO: https://eips.ethereum.org/EIPS/eip-3156
    function flashloan(
        address _token,
        uint256 _assets,
        address _borrower,
        address _receiver,
        bytes memory _flashloanReceiverData
    ) external returns (uint256 shares);
    // TODO: is euler style leverage safe?
    function leverage() external;
    // TODO: use flag that will mark pending liquidaiton position
    function liquidate(address _borrower) external;
    function accrueInterest(address _token) external returns (uint256 accruedInterest);
}
