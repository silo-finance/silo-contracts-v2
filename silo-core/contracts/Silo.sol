// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.17;

import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";

import "./interface/ISilo.sol";
import "./interface/ISiloConfig.sol";
import "./interface/ISiloFactory.sol";
import "./lib/SiloStdLib.sol";

abstract contract Silo is Initializable, ISilo {
    string public constant VERSION = "2.0.0";

    ISiloFactory public immutable FACTORY;

    ISiloConfig public config;

    mapping(address => AssetStorage) public assetStorage;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(ISiloFactory _factory) {
        FACTORY = _factory;
        _disableInitializers();
    }

    /// @notice Sets configuration
    /// @param _config address of ISiloConfig with full config for this Silo
    function initialize(ISiloConfig _config) external initializer {
        config = _config;
    }

    function siloId() external view virtual returns (uint256) {
        return config.SILO_ID();
    }

    function token0() external view virtual returns (address) {
        return config.token0();
    }

    function token1() external view virtual returns (address) {
        return config.token1();
    }

    function isSolvent(address _borrower) external virtual returns (bool) {
        return SiloStdLib.isSolvent(config, _borrower, assetStorage);
    }

    function depositPossible(address _token, address _depositor) external view virtual returns (bool) {
        return SiloStdLib.depositPossible(config, _token, _depositor);
    }

    function borrowPossible(address _token, address _borrower) external view virtual returns (bool) {
        return SiloStdLib.borrowPossible(config, _token, _borrower);
    }

    function getMaxLtv(address _token) external view virtual returns (uint256) {
        return SiloStdLib.getMaxLtv(config, _token);
    }

    function getLt(address _token) external view virtual returns (uint256) {
        return SiloStdLib.getLt(config, _token);
    }

    /**
     * ERC4626 *
     */

    function tokens() external view virtual returns (address[2] memory assetTokenAddresses) {
        return SiloStdLib.tokens(config);
    }

    function totalAssets(address _token) external view virtual returns (uint256 totalManagedAssets) {
        return SiloStdLib.totalAssets(config, _token, assetStorage);
    }

    /**
     * Deposits *
     */

    function convertToShares(address _token, uint256 _assets) external view virtual returns (uint256 shares) {
        return SiloStdLib.convertToShares(config, _token, _assets, false, false, assetStorage);
    }

    function convertToAssets(address _token, uint256 _shares) external view virtual returns (uint256 assets) {
        return SiloStdLib.convertToAssets(config, _token, _shares, false, false, assetStorage);
    }

    function maxDeposit(address _token, address _receiver) external view virtual returns (uint256 maxAssets) {
        return SiloStdLib.maxDeposit(config, _receiver, _token, false, assetStorage);
    }

    function previewDeposit(address _token, uint256 _assets) external view virtual returns (uint256 shares) {
        return SiloStdLib.previewDeposit(config, msg.sender, _token, _assets, false, assetStorage);
    }

    function deposit(address _token, uint256 _assets, address _receiver) external virtual returns (uint256 shares) {
        return SiloStdLib.deposit(config, FACTORY, _token, msg.sender, _receiver, _assets, false, assetStorage);
    }

    function maxMint(address _token, address _receiver) external view virtual returns (uint256 maxShares) {
        return SiloStdLib.maxMint(config, _receiver, _token, false);
    }

    function previewMint(address _token, uint256 _shares) external view virtual returns (uint256 assets) {
        return SiloStdLib.previewMint(config, msg.sender, _token, _shares, false, assetStorage);
    }

    function mint(address _token, uint256 _shares, address _receiver) external virtual returns (uint256 assets) {
        return SiloStdLib.mint(config, FACTORY, _token, msg.sender, _receiver, _shares, false, assetStorage);
    }

    function maxWithdraw(address _token, address _owner) external view virtual returns (uint256 maxAssets) {
        return SiloStdLib.maxWithdraw(config, _token, _owner, false, assetStorage);
    }

    function previewWithdraw(address _token, uint256 _assets) external view virtual returns (uint256 shares) {
        return SiloStdLib.previewWithdraw(config, _token, _assets, false, assetStorage);
    }

    function withdraw(address _token, uint256 _assets, address _receiver, address _owner)
        external
        virtual
        returns (uint256 shares)
    {
        return SiloStdLib.withdraw(config, FACTORY, _token, _assets, _receiver, _owner, msg.sender, false, assetStorage);
    }

    function maxRedeem(address _token, address _owner) external view virtual returns (uint256 maxShares) {
        return SiloStdLib.maxRedeem(config, _token, _owner, false, assetStorage);
    }

    function previewRedeem(address _token, uint256 _shares) external view virtual returns (uint256 assets) {
        return SiloStdLib.previewRedeem(config, _token, _shares, false, assetStorage);
    }

    function redeem(address _token, uint256 _shares, address _receiver, address _owner)
        external
        virtual
        returns (uint256 assets)
    {
        return SiloStdLib.redeem(config, FACTORY, _token, _shares, _receiver, _owner, msg.sender, false, assetStorage);
    }

    function accrueInterest(address _token) external virtual returns (uint256 accruedInterest) {
        return SiloStdLib.accrueInterest(config, FACTORY, _token, assetStorage);
    }

    /**
     * Protected Deposits *
     */

    function convertToShares(address _token, uint256 _assets, bool _isProtected)
        external
        view
        virtual
        returns (uint256 shares)
    {
        return SiloStdLib.convertToShares(config, _token, _assets, _isProtected, false, assetStorage);
    }

    function convertToAssets(address _token, uint256 _shares, bool _isProtected)
        external
        view
        virtual
        returns (uint256 assets)
    {
        return SiloStdLib.convertToAssets(config, _token, _shares, _isProtected, false, assetStorage);
    }

    function maxDeposit(address _token, address _receiver, bool _isProtected)
        external
        view
        virtual
        returns (uint256 maxAssets)
    {
        return SiloStdLib.maxDeposit(config, _receiver, _token, _isProtected, assetStorage);
    }

    function previewDeposit(address _token, uint256 _assets, bool _isProtected)
        external
        view
        virtual
        returns (uint256 shares)
    {
        return SiloStdLib.previewDeposit(config, msg.sender, _token, _assets, _isProtected, assetStorage);
    }

    function deposit(address _token, uint256 _assets, address _receiver, bool _isProtected)
        external
        virtual
        returns (uint256 shares)
    {
        return SiloStdLib.deposit(config, FACTORY, _token, msg.sender, _receiver, _assets, _isProtected, assetStorage);
    }

    function maxMint(address _token, address _receiver, bool _isProtected)
        external
        view
        virtual
        returns (uint256 maxShares)
    {
        return SiloStdLib.maxMint(config, _receiver, _token, _isProtected);
    }

    function previewMint(address _token, uint256 _shares, bool _isProtected)
        external
        view
        virtual
        returns (uint256 assets)
    {
        return SiloStdLib.previewMint(config, msg.sender, _token, _shares, _isProtected, assetStorage);
    }

    function mint(address _token, uint256 _shares, address _receiver, bool _isProtected)
        external
        virtual
        returns (uint256 assets)
    {
        return SiloStdLib.mint(config, FACTORY, _token, msg.sender, _receiver, _shares, _isProtected, assetStorage);
    }

    function maxWithdraw(address _token, address _owner, bool _isProtected)
        external
        view
        virtual
        returns (uint256 maxAssets)
    {
        return SiloStdLib.maxWithdraw(config, _token, _owner, _isProtected, assetStorage);
    }

    function previewWithdraw(address _token, uint256 _assets, bool _isProtected)
        external
        view
        virtual
        returns (uint256 shares)
    {
        return SiloStdLib.previewWithdraw(config, _token, _assets, _isProtected, assetStorage);
    }

    function withdraw(address _token, uint256 _assets, address _receiver, address _owner, bool _isProtected)
        external
        virtual
        returns (uint256 shares)
    {
        return SiloStdLib.withdraw(config, FACTORY, _token, _assets, _receiver, _owner, msg.sender, _isProtected, assetStorage);
    }

    function maxRedeem(address _token, address _owner, bool _isProtected)
        external
        view
        virtual
        returns (uint256 maxShares)
    {
        return SiloStdLib.maxRedeem(config, _token, _owner, _isProtected, assetStorage);
    }

    function previewRedeem(address _token, uint256 _shares, bool _isProtected)
        external
        view
        virtual
        returns (uint256 assets)
    {
        return SiloStdLib.previewRedeem(config, _token, _shares, _isProtected, assetStorage);
    }

    function redeem(address _token, uint256 _shares, address _receiver, address _owner, bool _isProtected)
        external
        virtual
        returns (uint256 assets)
    {
        return SiloStdLib.redeem(config, FACTORY, _token, _shares, _receiver, _owner, msg.sender, _isProtected, assetStorage);
    }

    function transitionToProtected(address _token, uint256 _shares, address _owner)
        external
        virtual
        returns (uint256 assets)
    {
        return SiloStdLib.transitionToProtected(config, FACTORY, _token, _shares, _owner, msg.sender, assetStorage);
    }

    function transitionFromProtected(address _token, uint256 _shares, address _owner)
        external
        virtual
        returns (uint256 shares)
    {
        return SiloStdLib.transitionFromProtected(config, FACTORY, _token, _shares, _owner, msg.sender, assetStorage);
    }

    /**
     * Lending *
     */

    function maxBorrow(address _token, address _borrower) external view virtual returns (uint256 maxAssets) {
        return SiloStdLib.maxBorrow(config, _token, _borrower, assetStorage);
    }

    function previewBorrow(address _token, uint256 _assets) external view virtual returns (uint256 shares) {
        return SiloStdLib.previewBorrow(config, _token, _assets, assetStorage);
    }

    function borrow(address _token, uint256 _assets, address _receiver, address _borrower)
        external
        virtual
        returns (uint256 shares)
    {}
}
