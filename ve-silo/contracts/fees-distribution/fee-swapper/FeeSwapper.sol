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

pragma solidity 0.8.19;

import {FeeSwapperConfig, IFeeSwapper, IERC20} from "./FeeSwapperConfig.sol";
import {IFeeSwap} from "../interfaces/IFeeSwap.sol";
import {IFeeDistributor} from "../interfaces/IFeeDistributor.sol";
import {IBalancerVaultLike as Vault, IAsset} from "../interfaces/IBalancerVaultLike.sol";

contract FeeSwapper is FeeSwapperConfig {
    // solhint-disable var-name-mixedcase
    IERC20 immutable public WETH;
    IERC20 immutable public LP_TOKEN;
    IERC20 immutable public SILO_TOKEN;
    IFeeDistributor immutable public FEE_DISTRIBUTOR;
    Vault immutable public BALANCER_VAULT;
    bytes32 immutable public BALANCER_POOL_ID;
    // solhint-enable var-name-mixedcase

    error SwapperIsNotConfigured(address _asset);

    constructor(
        IERC20 _weth,
        IERC20 _lpToken,
        IERC20 _siloToken,
        address _vault,
        bytes32 _poolId,
        IFeeDistributor _feeDistributor,
        SwapperConfigInput[] memory _configs
    ) FeeSwapperConfig(_configs) {
        WETH = _weth;
        FEE_DISTRIBUTOR = _feeDistributor;
        LP_TOKEN = _lpToken;
        SILO_TOKEN = _siloToken;
        BALANCER_VAULT = Vault(_vault);
        BALANCER_POOL_ID = _poolId;
    }

    function swapFeesAndDeposit(address[] calldata _assets) external virtual {
        _swapFees(_assets);
        _depositIntoBalancer();
        _depositLPTokens(type(uint256).max);
    }

    /// @inheritdoc IFeeSwapper
    function joinBalancerPool() external virtual {
        _depositIntoBalancer();
    }

    /// @inheritdoc IFeeSwapper
    function depositLPTokens(uint256 _amount) external virtual {
        _depositLPTokens(_amount);
    }

    /// @inheritdoc IFeeSwapper
    function swapFees(address[] calldata _assets) external virtual {
        _swapFees(_assets);
    }

    /// @notice Deposit into SILO-80%/WEH-20% Balancer pool
    function _depositIntoBalancer() internal virtual {
        uint256 wethBalance = WETH.balanceOf(address(this));

        IAsset[] memory assets = new IAsset[](2);
        assets[0] = IAsset(address(SILO_TOKEN));
        assets[1] = IAsset(address(WETH));

        uint256[] memory maxAmountsIn = new uint256[](2);
        maxAmountsIn[0] = 0; // depositing only WETH
        maxAmountsIn[1] = wethBalance;

        WETH.approve(address(BALANCER_VAULT), wethBalance);

        uint256 minimumBPT = 1;

        // userData: ['uint256', 'uint256[]', 'uint256']
        // userData: [EXACT_TOKENS_IN_FOR_BPT_OUT, amountsIn, minimumBPT]
        bytes memory userData = abi.encode(
            Vault.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT,
            maxAmountsIn,
            minimumBPT
        );

        Vault.JoinPoolRequest memory request = Vault.JoinPoolRequest({
            assets: assets,
            maxAmountsIn: maxAmountsIn,
            userData: userData,
            fromInternalBalance: false
        });

        BALANCER_VAULT.joinPool(
            BALANCER_POOL_ID,
            address(this),
            address(this),
            request
        );
    }

    /// @notice Deposit 80%/20% pool LP tokens in the `FeeDistributor`
    /// @param _amount Amount to be deposited into the `FeeDistributor`.
    /// If `uint256` max the current balance of the `FeeSwapper` will be deposited.
    function _depositLPTokens(uint256 _amount) internal virtual {
        uint256 amountToDistribute = _amount;

        if (_amount == type(uint256).max) {
            amountToDistribute = LP_TOKEN.balanceOf(address(this));
        }

        LP_TOKEN.approve(address(FEE_DISTRIBUTOR), amountToDistribute);

        FEE_DISTRIBUTOR.depositToken(LP_TOKEN, amountToDistribute);
        FEE_DISTRIBUTOR.checkpoint();
        FEE_DISTRIBUTOR.checkpointToken(LP_TOKEN);
    }

    /// @notice Swap all provided assets into WETH
    /// @param _assets A list of the asset to swap
    function _swapFees(address[] memory _assets) internal virtual {
        for (uint256 i; i < _assets.length;) {
            IERC20 asset = IERC20(_assets[i]);

            // Because of the condition, `i < _assets.length` overflow is impossible
            unchecked { i++; }

            if (asset == WETH) continue;

            uint256 amount = asset.balanceOf(address(this));

            IFeeSwap feeSwap = swappers[asset];

            if (address(feeSwap) == address(0)) revert SwapperIsNotConfigured(address(asset));

            asset.transfer(address(feeSwap), amount);

            // perform swap: asset -> WETH
            feeSwap.swap(asset, amount);
        }
    }
}
