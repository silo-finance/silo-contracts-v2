// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin5/interfaces/IERC20Metadata.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {SiloStorageLib} from "./SiloStorageLib.sol";

library VaultShareTokenLib {
    string private constant _NAME = "SiloShareToken";

    function approve(address _spender, uint256 _amount) internal returns (bool) {
        (bool result,) = _delegateCall(abi.encodeCall(IERC20.approve, (_spender, _amount)));

        return result;
    }

    function transfer(address _to, uint256 _amount) internal returns (bool) {
        (bool result,) = _delegateCall(abi.encodeCall(IERC20.transfer, (_to, _amount)));

        return result;
    }

    function transferFrom(address _from, address _to, uint256 _amount) internal returns (bool) {
        (bool result,) = _delegateCall(abi.encodeCall(IERC20.transferFrom, (_from, _to, _amount)));

        return result;
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

    function allowance(address _owner, address _spender) internal view returns (uint256) {
    }

    function balanceOf(address _owner) internal view returns (uint256) {
    }

    function totalSupply() internal view returns (uint256) {
    }

    function _delegateCall(bytes memory txPayload) private returns (bool success, bytes memory returnData) {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();
        (success, returnData) = $.vaultTokenImpl.delegatecall(txPayload);
    }
}
