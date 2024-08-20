// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ISilo, IERC20, IERC20Metadata} from "../interfaces/ISilo.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {NonReentrantLib} from "../lib/NonReentrantLib.sol";
import {SiloStorageLib} from "../lib/SiloStorageLib.sol";
import {VaultShareTokenLib} from "../lib/VaultShareTokenLib.sol";
import {VaultShareTokenViewLib} from "../lib/VaultShareTokenViewLib.sol";

abstract contract SiloERC4626 is ISilo {
    error OnlySilo();

    /// @inheritdoc IERC20
    function approve(address _spender, uint256 _amount) external returns (bool) {
        return VaultShareTokenLib.approve(_spender, _amount);
    }

    /// @inheritdoc IERC20
    function transfer(address _to, uint256 _amount) external returns (bool) {
        return VaultShareTokenLib.transfer(_to, _amount);
    }

    /// @inheritdoc IERC20
    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool) {
        return VaultShareTokenLib.transferFrom(_from, _to, _amount);
    }

    function forwardTransferFromNoChecks(address _from, address _to, uint256 _amount) external {
        VaultShareTokenLib.forwardTransferFromNoChecks(_from, _to, _amount);
    }

    function mintShares(address _owner, address, uint256 _amount) external {
        if (msg.sender != address(this)) revert OnlySilo();
        VaultShareTokenLib.mintShares(_owner, _amount);
    }

    function burn(address _owner, address _spender, uint256 _amount) external {
        if (msg.sender != address(this)) revert OnlySilo();
        VaultShareTokenLib.burn(_owner, _spender, _amount);
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        VaultShareTokenLib.permit(owner, spender, value, deadline, v, r, s);
    }

    /// @inheritdoc IERC20Metadata
    function decimals() external view virtual returns (uint8) {
        return VaultShareTokenViewLib.decimals();
    }

    /// @inheritdoc IERC20Metadata
    function name() external view virtual returns (string memory) {
        return VaultShareTokenViewLib.name();
    }

    /// @inheritdoc IERC20Metadata
    function symbol() external view virtual returns (string memory) {
        return VaultShareTokenViewLib.symbol();
    }

    /// @inheritdoc IERC20
    function allowance(address _owner, address _spender) external view returns (uint256) {
        return VaultShareTokenViewLib.allowance(_owner, _spender);
    }

    /// @inheritdoc IERC20
    function balanceOf(address _account) external view returns (uint256) {
        return VaultShareTokenViewLib.balanceOf(_account);
    }

    /// @inheritdoc IERC20
    function totalSupply() external view returns (uint256) {
        return VaultShareTokenViewLib.totalSupply();
    }

    function nonces(address owner) external view returns (uint256) {
        return VaultShareTokenViewLib.nonces(owner);
    }

    function hookReceiver() external view returns (address) {
        return VaultShareTokenViewLib.hookReceiver();
    }

    function hookSetup() external view returns (IShareToken.HookSetup memory) {
        return VaultShareTokenViewLib.hookSetup();
    }

    function balanceOfAndTotalSupply(address _account) external view returns (uint256 balance, uint256 supply) {
        balance = VaultShareTokenViewLib.balanceOf(_account);
        supply = VaultShareTokenViewLib.totalSupply();
    }

    function silo() external view returns (ISilo) {
        return this;
    }
}
