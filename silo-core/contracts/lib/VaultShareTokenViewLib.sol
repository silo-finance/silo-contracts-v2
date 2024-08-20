// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin5/interfaces/IERC20Metadata.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {SiloStorageLib} from "./SiloStorageLib.sol";

library VaultShareTokenViewLib {
    string private constant _NAME = "SiloShareToken";

    /// @custom:storage-location erc7201:openzeppelin.storage.ERC20
    struct ERC20Storage {
        mapping(address account => uint256) _balances;

        mapping(address account => mapping(address spender => uint256)) _allowances;

        uint256 _totalSupply;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC20")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC20StorageLocation = 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00;

    function _getERC20Storage() private pure returns (ERC20Storage storage $) {
        assembly {
            $.slot := ERC20StorageLocation
        }
    }

    function allowance(address _owner, address _spender) internal view returns (uint256) {
        return _getERC20Storage()._allowances[_owner][_spender];
    }

    function balanceOf(address _owner) internal view returns (uint256) {
        return _getERC20Storage()._balances[_owner];
    }

    function totalSupply() internal view returns (uint256) {
        return _getERC20Storage()._totalSupply;
    }

    function decimals() internal view returns (uint8) {
        return 18;
    }

    function name() internal view returns (string memory) {
        return _NAME;
    }

    function symbol() internal view returns (string memory) {
        return _NAME;
    }
}
