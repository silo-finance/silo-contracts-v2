// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin5/interfaces/IERC20Metadata.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {Hook} from "./Hook.sol";
import {SiloStorageLib} from "./SiloStorageLib.sol";

library VaultShareTokenViewLib {
    string private constant _NAME = "SiloShareToken";

    /// @custom:storage-location erc7201:openzeppelin.storage.ERC20
    struct ERC20Storage {
        mapping(address account => uint256) _balances;

        mapping(address account => mapping(address spender => uint256)) _allowances;

        uint256 _totalSupply;
    }

    /// @custom:storage-location erc7201:openzeppelin.storage.Nonces
    struct NoncesStorage {
        mapping(address account => uint256) _nonces;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC20")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC20StorageLocation = 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00;

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Nonces")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant NoncesStorageLocation = 0x5ab42ced628888259c08ac98db1eb0cf702fc1501344311d8b100cd1bfe4bb00;

    function _getERC20Storage() private pure returns (ERC20Storage storage $) {
        assembly {
            $.slot := ERC20StorageLocation
        }
    }

    function _getNoncesStorage() private pure returns (NoncesStorage storage $) {
        assembly {
            $.slot := NoncesStorageLocation
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

    function decimals() internal pure returns (uint8) {
        return 18;
    }

    function name() internal pure returns (string memory) {
        return _NAME;
    }

    function symbol() internal pure returns (string memory) {
        return _NAME;
    }

    function nonces(address _owner) external view returns (uint256) {
        return _getNoncesStorage()._nonces[_owner];
    }

    function hookReceiver() external view returns (address) {
        return address(SiloStorageLib.getSiloStorage().sharedStorage.hookReceiver);
    }

    function hookSetup() external view returns (IShareToken.HookSetup memory) {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();

        return IShareToken.HookSetup({
            hookReceiver: address($.sharedStorage.hookReceiver),
            hooksBefore: $.sharedStorage.hooksBefore,
            hooksAfter: $.sharedStorage.hooksAfter,
            tokenType: uint24(Hook.COLLATERAL_TOKEN)
        });
    }
}
