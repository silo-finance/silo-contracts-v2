// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin5/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "openzeppelin5/token/ERC20/extensions/ERC20Permit.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloStorageLib} from "./SiloStorageLib.sol";

library VaultShareTokenLib {
    function approve(address _spender, uint256 _amount) internal returns (bool result) {
        (result,) = _delegateCall(abi.encodeCall(IERC20.approve, (_spender, _amount)));
    }

    function transfer(address _to, uint256 _amount) internal returns (bool result) {
        (result,) = _delegateCall(abi.encodeCall(IERC20.transfer, (_to, _amount)));
    }

    function transferFrom(address _from, address _to, uint256 _amount) internal returns (bool result) {
        (result,) = _delegateCall(abi.encodeCall(IERC20.transferFrom, (_from, _to, _amount)));
    }

    function mintShares(address _owner, uint256 _amount) external {
        _delegateCall(abi.encodeCall(IShareToken.mintShares, (_owner, address(0), _amount)));
    }

    function burn(address _owner, address _spender, uint256 _amount) external {
        _delegateCall(abi.encodeCall(IShareToken.burn, (_owner, _spender, _amount)));
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        bytes memory txPayload = abi.encodeCall(
            IERC20Permit.permit,
            (
                owner,
                spender,
                value,
                deadline,
                v,
                r,
                s
            )
        );

        _delegateCall(txPayload);
    }

    function _delegateCall(bytes memory txPayload) private returns (bool success, bytes memory returnData) {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();
        (success, returnData) = $.vaultTokenImpl.delegatecall(txPayload);
    }
}
