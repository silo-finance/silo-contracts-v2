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

import {IERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";

import {IFeeSwap} from "../interfaces/IFeeSwap.sol";
import {IFeeSwapper} from "../interfaces/IFeeSwapper.sol";
import {IFeeDistributor} from "../interfaces/IFeeDistributor.sol";
import {ExtendedOwnable} from "ve-silo/contracts/access/ExtendedOwnable.sol";

abstract contract FeeSwapperConfig is IFeeSwapper, ExtendedOwnable {
    mapping(IERC20 asset => IFeeSwap feeSwap) public swappers;

    event SwapperUpdated(IERC20 asset, IFeeSwap swapper);

    error SwapperAlreadyConfigured(IERC20 asset);

    constructor(SwapperConfigInput[] memory _configs) {
        _setSwappers(_configs);
    }

    /// @inheritdoc IFeeSwapper
    function setSwappers(SwapperConfigInput[] calldata _configs) external virtual onlyOwner {
        _setSwappers(_configs);
    }

    function _setSwappers(SwapperConfigInput[] memory _configs) internal virtual {
        for (uint i = 0; i < _configs.length;) {
            IERC20 asset = _configs[i].asset;
            IFeeSwap swap = _configs[i].swap;

            if (swappers[asset] == swap) revert SwapperAlreadyConfigured(asset);

            swappers[asset] = swap;

            emit SwapperUpdated(asset, swap);
            // Because of the condition, `i < _configs.length` overflow is impossible
            unchecked { i++; }
        }
    }
}
