// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity 0.8.24;

import {FeeSwapperConfig, IFeeSwapper, IERC20} from "./FeeSwapperConfig.sol";
import {IFeeSwap} from "../interfaces/IFeeSwap.sol";
import {IFeeDistributor} from "../interfaces/IFeeDistributor.sol";
import {IBalancerVaultLike as Vault, IAsset} from "../interfaces/IBalancerVaultLike.sol";

contract FeeSwapper is FeeSwapperConfig {
    // solhint-disable var-name-mixedcase
    IERC20 immutable public WETH;
    IERC20 immutable public SILO_TOKEN;
    IFeeDistributor immutable public FEE_DISTRIBUTOR;
    Vault immutable public BALANCER_VAULT;
    bytes32 immutable public BALANCER_POOL_ID;
    // solhint-enable var-name-mixedcase

    error ArraysLengthMissMutch();
    error SwapperIsNotConfigured(address _asset);

    constructor(
        IERC20 _weth,
        IERC20 _siloToken,
        address _vault,
        bytes32 _poolId,
        IFeeDistributor _feeDistributor,
        SwapperConfigInput[] memory _configs
    ) FeeSwapperConfig(_configs) {
        WETH = _weth;
        FEE_DISTRIBUTOR = _feeDistributor;
        SILO_TOKEN = _siloToken;
        BALANCER_VAULT = Vault(_vault);
        BALANCER_POOL_ID = _poolId;

        WETH.approve(address(BALANCER_VAULT), type(uint256).max);
        SILO_TOKEN.approve(address(FEE_DISTRIBUTOR), type(uint256).max);
    }

    function swapFeesAndDeposit(
        address[] calldata _assets,
        bytes[] memory _data,
        uint256 _siloExpectedAmount
    ) external onlyManager virtual {
        _swapFees(_assets, _data);
        _swapViaBalancer(_siloExpectedAmount);
        _depositSiloTokens(type(uint256).max);
    }

    /// @inheritdoc IFeeSwapper
    function getSiloTokens(uint256 _siloExpectedAmount) external virtual {
        _swapViaBalancer(_siloExpectedAmount);
    }

    /// @inheritdoc IFeeSwapper
    function depositSiloTokens(uint256 _amount) external virtual {
        _depositSiloTokens(_amount);
    }

    /// @inheritdoc IFeeSwapper
    function swapFees(address[] calldata _assets, bytes[] memory _data) external onlyManager virtual {
        _swapFees(_assets, _data);
    }

    /// @notice Swap WETH to SILO tokens
    function _swapViaBalancer(uint256 _siloExpectedAmount) internal virtual {
        uint256 wethBalance = WETH.balanceOf(address(this));

        Vault.SingleSwap memory singleSwap = Vault.SingleSwap(
            BALANCER_POOL_ID,
            Vault.SwapKind.GIVEN_IN,
            IAsset(address(WETH)),
            IAsset(address(SILO_TOKEN)),
            wethBalance,
            ""
        );

        Vault.FundManagement memory funds = Vault.FundManagement(
            address(this), false, payable(address(this)), false
        );

        BALANCER_VAULT.swap(singleSwap, funds, _siloExpectedAmount, block.timestamp);
    }

    /// @notice Deposit SILO tokens in the `FeeDistributor`
    /// @param _amount Amount to be deposited into the `FeeDistributor`.
    /// If `uint256` max the current balance of the `FeeSwapper` will be deposited.
    function _depositSiloTokens(uint256 _amount) internal virtual {
        uint256 amountToDistribute = _amount;

        if (_amount == type(uint256).max) {
            amountToDistribute = SILO_TOKEN.balanceOf(address(this));
        }

        FEE_DISTRIBUTOR.depositToken(SILO_TOKEN, amountToDistribute);
        FEE_DISTRIBUTOR.checkpoint();
        FEE_DISTRIBUTOR.checkpointToken(SILO_TOKEN);
    }

    /// @notice Swap all provided assets into WETH
    /// @param _assets A list of the asset to swap
    function _swapFees(address[] memory _assets, bytes[] memory _data) internal virtual {
        if (_assets.length != _data.length) revert ArraysLengthMissMutch();

        for (uint256 i; i < _assets.length;) {
            IERC20 asset = IERC20(_assets[i]);
            bytes memory data = _data[i];

            // Because of the condition, `i < _assets.length` overflow is impossible
            unchecked { i++; }

            if (asset == WETH) continue;

            uint256 amount = asset.balanceOf(address(this));

            IFeeSwap feeSwap = swappers[asset];

            if (address(feeSwap) == address(0)) revert SwapperIsNotConfigured(address(asset));

            asset.transfer(address(feeSwap), amount);

            // perform swap: asset -> WETH
            feeSwap.swap(asset, amount, data);
        }
    }
}
