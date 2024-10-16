// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IShareToken} from "../interfaces/IShareToken.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {IERC20R} from "../interfaces/IERC20R.sol";

import {ShareTokenLib} from "./ShareTokenLib.sol";
import {CallBeforeQuoteLib} from "../lib/CallBeforeQuoteLib.sol";

// TODO do we need lib here? debt token size is not a concern, so maybe we can avoid this lib, unless we want to move
// before/after share to `_update`.

// solhint-disable ordering

library ERC20RStorage {
    using CallBeforeQuoteLib for ISiloConfig.ConfigData;

    // keccak256(abi.encode(uint256(keccak256("silo.storage.ERC20R")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant _STORAGE_LOCATION = 0x5a499b742bad5e18c139447ced974d19a977bcf86e03691ee458d10efcd04d00;

    function getIERC20RStorage() internal pure returns (IERC20R.Storage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := _STORAGE_LOCATION
        }
    }
}
