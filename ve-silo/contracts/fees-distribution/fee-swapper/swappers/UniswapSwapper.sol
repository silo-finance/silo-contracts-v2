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

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";

import {IUniswapSwapRouterLike as ISwapRouter} from "./interfaces/IUniswapSwapRouterLike.sol";
import {IFeeSwap} from "../../interfaces/IFeeSwap.sol";

contract UniswapSwapper is IFeeSwap, Ownable2Step {
    struct SwapPath {
        IUniswapV3Pool pool;
        // if target/interim token is token0, then TRUE
        bool token0IsInterim;
    }

    ISwapRouter public immutable router;

    mapping(IERC20 => SwapPath[]) public config;

    event ConfigUpdated(IERC20 asset);

    error RouterIsZero();
    error AssetIsZero();
    error AssetIsNotConfigured();
    error PoolNotSet();

    constructor (address _router) Ownable(msg.sender) {
        if (_router == address(0)) revert RouterIsZero();

        router = ISwapRouter(_router);
    }

    /// @inheritdoc IFeeSwap
    function swap(IERC20 _asset, uint256 _amount, bytes memory _data) external {
        SwapPath[] memory swapPath = config[_asset];

        if (swapPath.length == 0) revert AssetIsNotConfigured();

        (uint256 amountOutMinimum) = abi.decode(_data, (uint256));

        bytes memory path = createPath(swapPath);

        _asset.approve(address(router), _amount);

        ISwapRouter.ExactInputParams memory params =
            ISwapRouter.ExactInputParams({
            path: path,
            recipient: msg.sender,
            deadline: block.timestamp,
            amountIn: _amount,
            amountOutMinimum: amountOutMinimum
        });

        router.exactInput(params);
    }

    /// @notice Update an asset swap configuration
    /// @param _swapPath Swap path
    function configurePath(IERC20 _asset, SwapPath[] calldata _swapPath) external onlyOwner {
        if (address(_asset) == address(0)) revert AssetIsZero();

        delete config[_asset];

        for (uint256 i = 0; i < _swapPath.length;) {
            config[_asset].push(_swapPath[i]);

            // we will not overflow because we stop at i == _swapPath.length
            unchecked { i++;}
        }

        emit ConfigUpdated(_asset);
    }

    /// @param _swapPath asset swap path
    /// @return path The path is a sequence of (tokenAddress - fee - tokenAddress), which are the variables needed to
    /// compute each pool contract address in our sequence of swaps. The multihop swap router code will automatically
    /// find the correct pool with these variables, and execute the swap needed within each pool in our sequence.
    /// see https://docs.uniswap.org/protocol/guides/swaps/multihop-swaps#input-parameters
    function createPath(SwapPath[] memory _swapPath)
        public
        virtual
        view
        returns (bytes memory path)
    {
        for (uint256 i = 0; i < _swapPath.length;) {
            (address token0, address token1) = (_swapPath[i].pool.token0(), _swapPath[i].pool.token1());
            (address from, address target) = _swapPath[i].token0IsInterim ? (token1, token0) : (token0, token1);

            if (i == _swapPath.length - 1) {
                path = abi.encodePacked(path, from, _swapPath[i].pool.fee(), target);
            } else {
                path = abi.encodePacked(path, from, _swapPath[i].pool.fee());
            }

            // we will not overflow because we stop at i == _swapPath.length
            unchecked { i++;}
        }
    }
}
