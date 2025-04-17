// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {ERC20, ERC4626} from "openzeppelin5/token/ERC20/extensions/ERC4626.sol";
import {IERC4626, IERC20} from "openzeppelin5/interfaces/IERC4626.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";

contract IdleVault is ERC4626 {
    /// @dev this is the only user that is allowed to deposit
    address public immutable ONLY_DEPOSITOR;

    /// @dev Initializes the contract.
    /// @param onlyDepositor The only user allowed to use vault.
    /// @param _asset The address of the underlying asset.
    /// @param _name The name of the vault.
    /// @param _symbol The symbol of the vault.
    constructor(
        address onlyDepositor,
        address _asset,
        string memory _name,
        string memory _symbol
    ) ERC4626(IERC20(_asset)) ERC20(_name, _symbol) {
        if (onlyDepositor == address(0)) revert ErrorsLib.ZeroAddress();

        ONLY_DEPOSITOR = onlyDepositor;
    }

    /// @inheritdoc IERC4626
    function maxDeposit(address _depositor) public view virtual override returns (uint256) {
        return _depositor != ONLY_DEPOSITOR ? 0 : super.maxDeposit(_depositor);
    }

    /// @inheritdoc IERC4626
    function maxMint(address _depositor) public view virtual override returns (uint256) {
        return _depositor != ONLY_DEPOSITOR ? 0 : super.maxMint(_depositor);
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 _assets, address _receiver) public virtual override returns (uint256 shares) {
        if (_receiver != ONLY_DEPOSITOR) revert();

        return super.deposit(_assets, _receiver);
    }

    /// @inheritdoc IERC4626
    function mint(uint256 _shares, address _receiver) public virtual override returns (uint256 assets) {
        if (_receiver != ONLY_DEPOSITOR) revert();

        return super.mint(_shares, _receiver);
    }

    /// @notice This would make the amount that the user would need to "gift" the market in order to significantly
    /// inflate the share price very large and impractical.
    function _decimalsOffset() internal view virtual override returns (uint8) {
        return 6;
    }
}
