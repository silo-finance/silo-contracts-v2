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

pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";

import {IFeeSwap} from "./IFeeSwap.sol";

interface IFeeSwapper {
    struct SwapperConfigInput {
        IERC20 asset;
        IFeeSwap swap;
    }

    function swapFeesAndDeposit(
        address[] calldata _assets,
        bytes[] memory _data,
        uint256 _siloExpectedAmount
    ) external;

    /// @notice Swap WETH to SILO tokens
    function getSiloTokens(uint256 _siloExpectedAmount) external;

    /// @notice Deposit SILO tokens in the `FeeDistributor`
    /// @param _amount Amount to be deposited into the `FeeDistributor`.
    /// If `uint256` max the current balance of the `FeeSwapper` will be deposited.
    function depositSiloTokens(uint256 _amount) external;

    /// @notice Swap all provided assets into WETH
    /// @param _assets A list of the asset to swap
    /// @param _data Extra data that will be passed into a swap implementation.
    ///              For example encoded `amountOutMinimum` for an `UniswapSwapper`
    function swapFees(address[] calldata _assets, bytes[] memory _data) external;

    /// @notice Configure swappers
    /// @param _inputs Swappers configurations
    function setSwappers(SwapperConfigInput[] calldata _inputs) external;
}
