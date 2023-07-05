// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

import {ISilo} from "./interface/ISilo.sol";
import {ISiloConfig} from "./interface/ISiloConfig.sol";
import {ISiloFactory} from "./interface/ISiloFactory.sol";
import {SiloStdLib} from "./lib/SiloStdLib.sol";
import {SiloSolvencyLib} from "./lib/SiloSolvencyLib.sol";
import {SiloLendingLib} from "./lib/SiloLendingLib.sol";

// solhint-disable ordering

abstract contract Silo is Initializable, ISilo {
    string public constant VERSION = "2.0.0";

    ISiloFactory public immutable FACTORY; // solhint-disable-line var-name-mixedcase

    ISiloConfig public config;

    mapping(address => AssetStorage) public assetStorage;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(ISiloFactory _factory) {
        FACTORY = _factory;
        _disableInitializers();
    }

    /// @notice Sets configuration
    /// @param _config address of ISiloConfig with full config for this Silo
    function initialize(ISiloConfig _config) external virtual initializer {
        config = _config;
    }

    function siloId() external view virtual returns (uint256) {
        return config.SILO_ID();
    }

    function token0() external view virtual returns (address) {
        return config.TOKEN0();
    }

    function token1() external view virtual returns (address) {
        return config.TOKEN1();
    }

    function isSolvent(address _borrower) external virtual returns (bool) {
        // solhint-disable-line ordering
        return SiloSolvencyLib.isSolvent(config, _borrower, assetStorage);
    }

    function depositPossible(address _token, address _depositor) external view virtual returns (bool) {
        // TODO: caps
        return SiloLendingLib.depositPossible(config, _token, _depositor);
    }

    function borrowPossible(address _token, address _borrower) external view virtual returns (bool) {
        // TODO: caps
        return SiloLendingLib.borrowPossible(config, _token, _borrower);
    }

    function getMaxLtv(address _token) external view virtual returns (uint256) {
        return SiloSolvencyLib.getMaxLtv(config, _token);
    }

    function getLt(address _token) external view virtual returns (uint256) {
        return SiloSolvencyLib.getLt(config, _token);
    }

    // ERC4626-ish

    function tokens() external view virtual returns (address[2] memory assetTokenAddresses) {
        return SiloStdLib.tokens(config);
    }

    function totalAssets(address _token) external view virtual returns (uint256 totalManagedAssets) {
        return SiloStdLib.totalAssets(config, _token, assetStorage);
    }

    function convertToShares(address _token, uint256 _assets) external view virtual returns (uint256 shares) {
        return SiloStdLib.convertToShares(config, _token, _assets, SiloStdLib.TokenType.Collateral, assetStorage);
    }

    function convertToAssets(address _token, uint256 _shares) external view virtual returns (uint256 assets) {
        return SiloStdLib.convertToAssets(config, _token, _shares, SiloStdLib.TokenType.Collateral, assetStorage);
    }

    function maxDeposit(address _token, address _receiver) external view virtual returns (uint256 maxAssets) {
        // TODO: caps
        return SiloLendingLib.maxDeposit(config, _receiver, _token, false, assetStorage);
    }

    function previewDeposit(address _token, uint256 _assets) external view virtual returns (uint256 shares) {
        return SiloLendingLib.previewDeposit(config, msg.sender, _token, _assets, false, assetStorage);
    }

    function deposit(address _token, uint256 _assets, address _receiver) external virtual returns (uint256 shares) {
        return SiloLendingLib.deposit(config, FACTORY, _token, msg.sender, _receiver, _assets, false, assetStorage);
    }

    function maxMint(address _token, address _receiver) external view virtual returns (uint256 maxShares) {
        // TODO: caps
        return SiloLendingLib.maxMint(config, _receiver, _token, false);
    }

    function previewMint(address _token, uint256 _shares) external view virtual returns (uint256 assets) {
        return SiloLendingLib.previewMint(config, msg.sender, _token, _shares, false, assetStorage);
    }

    function mint(address _token, uint256 _shares, address _receiver) external virtual returns (uint256 assets) {
        return SiloLendingLib.mint(config, FACTORY, _token, msg.sender, _receiver, _shares, false, assetStorage);
    }

    function maxWithdraw(address _token, address _owner) external view virtual returns (uint256 maxAssets) {
        return SiloLendingLib.maxWithdraw(config, _token, _owner, false, assetStorage);
    }

    function previewWithdraw(address _token, uint256 _assets) external view virtual returns (uint256 shares) {
        return SiloLendingLib.previewWithdraw(config, _token, _assets, false, assetStorage);
    }

    function withdraw(address _token, uint256 _assets, address _receiver, address _owner)
        external
        virtual
        returns (uint256 shares)
    {
        return SiloLendingLib.withdraw(
            config, FACTORY, _token, _assets, _receiver, _owner, msg.sender, false, assetStorage
        );
    }

    function maxRedeem(address _token, address _owner) external view virtual returns (uint256 maxShares) {
        return SiloLendingLib.maxRedeem(config, _token, _owner, false, assetStorage);
    }

    function previewRedeem(address _token, uint256 _shares) external view virtual returns (uint256 assets) {
        return SiloLendingLib.previewRedeem(config, _token, _shares, false, assetStorage);
    }

    function redeem(address _token, uint256 _shares, address _receiver, address _owner)
        external
        virtual
        returns (uint256 assets)
    {
        return
            SiloLendingLib.redeem(config, FACTORY, _token, _shares, _receiver, _owner, msg.sender, false, assetStorage);
    }

    function accrueInterest(address _token) external virtual returns (uint256 accruedInterest) {
        return SiloLendingLib.accrueInterest(config, FACTORY, _token, assetStorage);
    }

    // Protected

    function convertToShares(address _token, uint256 _assets, bool _isProtected)
        external
        view
        virtual
        returns (uint256 shares)
    {
        SiloStdLib.TokenType tokenType = SiloStdLib.TokenType.Collateral;
        if (_isProtected) tokenType = SiloStdLib.TokenType.Protected;

        return SiloStdLib.convertToShares(config, _token, _assets, tokenType, assetStorage);
    }

    function convertToAssets(address _token, uint256 _shares, bool _isProtected)
        external
        view
        virtual
        returns (uint256 assets)
    {
        SiloStdLib.TokenType tokenType = SiloStdLib.TokenType.Collateral;
        if (_isProtected) tokenType = SiloStdLib.TokenType.Protected;

        return SiloStdLib.convertToAssets(config, _token, _shares, tokenType, assetStorage);
    }

    function maxDeposit(address _token, address _receiver, bool _isProtected)
        external
        view
        virtual
        returns (uint256 maxAssets)
    {
        return SiloLendingLib.maxDeposit(config, _receiver, _token, _isProtected, assetStorage);
    }

    function previewDeposit(address _token, uint256 _assets, bool _isProtected)
        external
        view
        virtual
        returns (uint256 shares)
    {
        return SiloLendingLib.previewDeposit(config, msg.sender, _token, _assets, _isProtected, assetStorage);
    }

    function deposit(address _token, uint256 _assets, address _receiver, bool _isProtected)
        external
        virtual
        returns (uint256 shares)
    {
        return
            SiloLendingLib.deposit(config, FACTORY, _token, msg.sender, _receiver, _assets, _isProtected, assetStorage);
    }

    function maxMint(address _token, address _receiver, bool _isProtected)
        external
        view
        virtual
        returns (uint256 maxShares)
    {
        return SiloLendingLib.maxMint(config, _receiver, _token, _isProtected);
    }

    function previewMint(address _token, uint256 _shares, bool _isProtected)
        external
        view
        virtual
        returns (uint256 assets)
    {
        return SiloLendingLib.previewMint(config, msg.sender, _token, _shares, _isProtected, assetStorage);
    }

    function mint(address _token, uint256 _shares, address _receiver, bool _isProtected)
        external
        virtual
        returns (uint256 assets)
    {
        return SiloLendingLib.mint(config, FACTORY, _token, msg.sender, _receiver, _shares, _isProtected, assetStorage);
    }

    function maxWithdraw(address _token, address _owner, bool _isProtected)
        external
        view
        virtual
        returns (uint256 maxAssets)
    {
        return SiloLendingLib.maxWithdraw(config, _token, _owner, _isProtected, assetStorage);
    }

    function previewWithdraw(address _token, uint256 _assets, bool _isProtected)
        external
        view
        virtual
        returns (uint256 shares)
    {
        return SiloLendingLib.previewWithdraw(config, _token, _assets, _isProtected, assetStorage);
    }

    function withdraw(address _token, uint256 _assets, address _receiver, address _owner, bool _isProtected)
        external
        virtual
        returns (uint256 shares)
    {
        return SiloLendingLib.withdraw(
            config, FACTORY, _token, _assets, _receiver, _owner, msg.sender, _isProtected, assetStorage
        );
    }

    function maxRedeem(address _token, address _owner, bool _isProtected)
        external
        view
        virtual
        returns (uint256 maxShares)
    {
        return SiloLendingLib.maxRedeem(config, _token, _owner, _isProtected, assetStorage);
    }

    function previewRedeem(address _token, uint256 _shares, bool _isProtected)
        external
        view
        virtual
        returns (uint256 assets)
    {
        return SiloLendingLib.previewRedeem(config, _token, _shares, _isProtected, assetStorage);
    }

    function redeem(address _token, uint256 _shares, address _receiver, address _owner, bool _isProtected)
        external
        virtual
        returns (uint256 assets)
    {
        return SiloLendingLib.redeem(
            config, FACTORY, _token, _shares, _receiver, _owner, msg.sender, _isProtected, assetStorage
        );
    }

    function transitionToProtected(address _token, uint256 _shares, address _owner)
        external
        virtual
        returns (uint256 assets)
    {
        return SiloLendingLib.transitionToProtected(config, FACTORY, _token, _shares, _owner, msg.sender, assetStorage);
    }

    function transitionFromProtected(address _token, uint256 _shares, address _owner)
        external
        virtual
        returns (uint256 shares)
    {
        return
            SiloLendingLib.transitionFromProtected(config, FACTORY, _token, _shares, _owner, msg.sender, assetStorage);
    }

    // Lending

    function maxBorrow(address _token, address _borrower) external view virtual returns (uint256 maxAssets) {
        return SiloLendingLib.maxBorrow(config, _token, _borrower, assetStorage);
    }

    function previewBorrow(address _token, uint256 _assets) external view virtual returns (uint256 shares) {
        return SiloLendingLib.previewBorrow(config, _token, _assets, assetStorage);
    }

    function borrow(address _token, uint256 _assets, address _receiver, address _borrower)
        external
        virtual
        returns (uint256 shares)
    {
        return SiloLendingLib.borrow(config, FACTORY, _token, _assets, _receiver, _borrower, msg.sender, assetStorage);
    }

    function maxBorrowShares(address _token, address _borrower) external view virtual returns (uint256 maxShares) {
        return SiloLendingLib.maxBorrowShares(config, _token, _borrower, assetStorage);
    }

    function previewBorrowShares(address _token, uint256 _shares) external view virtual returns (uint256 assets) {
        return SiloLendingLib.previewBorrowShares(config, _token, _shares, assetStorage);
    }

    function borrowShares(address _token, uint256 _shares, address _receiver, address _borrower)
        external
        virtual
        returns (uint256 assets)
    {
        return SiloLendingLib.borrowShares(
            config, FACTORY, _token, _shares, _receiver, _borrower, msg.sender, assetStorage
        );
    }

    function maxRepay(address _token, address _borrower) external view virtual returns (uint256 assets) {
        return SiloLendingLib.maxRepay(config, _token, _borrower, assetStorage);
    }

    function previewRepay(address _token, uint256 _assets) external view returns (uint256 shares) {
        return SiloLendingLib.previewRepay(config, _token, _assets, assetStorage);
    }

    function repay(address _token, uint256 _assets, address _borrower) external returns (uint256 shares) {
        return SiloLendingLib.repay(config, FACTORY, _token, _assets, _borrower, msg.sender, assetStorage);
    }

    function maxRepayShares(address _token, address _borrower) external view returns (uint256 shares) {
        return SiloLendingLib.maxRepayShares(config, _token, _borrower, assetStorage);
    }

    function previewRepayShares(address _token, uint256 _shares) external view returns (uint256 assets) {
        return SiloLendingLib.previewRepayShares(config, _token, _shares, assetStorage);
    }

    function repayShares(address _token, uint256 _shares, address _borrower) external returns (uint256 assets) {
        return SiloLendingLib.repayShares(config, FACTORY, _token, _shares, _borrower, msg.sender, assetStorage);
    }
}
