// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20R} from "../interfaces/IERC20R.sol";

library ERC20RStorageLib {
    // keccak256(abi.encode(uint256(keccak256("silo.storage.ERC20R")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant _STORAGE_LOCATION = 0x5a499b742bad5e18c139447ced974d19a977bcf86e03691ee458d10efcd04d00;

    function getIERC20RStorage() internal pure returns (IERC20R.Storage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := _STORAGE_LOCATION
        }
    }
}
