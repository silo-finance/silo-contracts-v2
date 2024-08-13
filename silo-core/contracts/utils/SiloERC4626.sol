// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ISilo, IERC20, IERC20Metadata} from "../interfaces/ISilo.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {NonReentrantLib} from "../lib/NonReentrantLib.sol";
import {SiloStorage} from "../SiloStorage.sol";

// TODO: make PoC for moving collateral token logic to SiloERC4626
// move evertyhing to SiloERC4626
// create internal interface for SiloERC4626
abstract contract SiloERC4626 is ISilo, SiloStorage {
    /// @inheritdoc IERC20
    function approve(address _spender, uint256 _amount) external returns (bool) {
        NonReentrantLib.nonReentrant(_sharedStorage.siloConfig);
        IShareToken(_getShareToken()).forwardApprove(msg.sender, _spender, _amount);

        return true;
    }

    /// @inheritdoc IERC20
    function transfer(address _to, uint256 _amount) external returns (bool) {
        ISiloConfig siloConfig = _sharedStorage.siloConfig;

        siloConfig.turnOnReentrancyProtection();
        // TODO: what about events? Will etherscan (and other UIs) show the correct balances? Should we move share token to Silo itself?
        IShareToken(_getShareToken()).forwardTransfer(msg.sender, _to, _amount);
        siloConfig.turnOffReentrancyProtection();

        return true;
    }

    /// @inheritdoc IERC20
    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool) {
        ISiloConfig siloConfig = _sharedStorage.siloConfig;

        siloConfig.turnOnReentrancyProtection();
        IShareToken(_getShareToken()).forwardTransferFrom(msg.sender, _from, _to, _amount);
        siloConfig.turnOffReentrancyProtection();

        return true;
    }

    /// @inheritdoc IERC20Metadata
    function decimals() external view virtual returns (uint8) {
        return IShareToken(_getShareToken()).decimals();
    }

    /// @inheritdoc IERC20Metadata
    function name() external view virtual returns (string memory) {
        return IShareToken(_getShareToken()).name();
    }

    /// @inheritdoc IERC20Metadata
    function symbol() external view virtual returns (string memory) {
        return IShareToken(_getShareToken()).symbol();
    }

    /// @inheritdoc IERC20
    function allowance(address _owner, address _spender) external view returns (uint256) {
        return IShareToken(_getShareToken()).allowance(_owner, _spender);
    }

    /// @inheritdoc IERC20
    function balanceOf(address _account) external view returns (uint256) {
        return IShareToken(_getShareToken()).balanceOf(_account);
    }

    /// @inheritdoc IERC20
    function totalSupply() external view returns (uint256) {
        return IShareToken(_getShareToken()).totalSupply();
    }

    function _getShareToken() internal view virtual returns (address collateralShareToken);
}
