// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/ERC20Permit.sol)

pragma solidity ^0.8.20;

import {IERC20Permit} from "openzeppelin5/token/ERC20/extensions/IERC20Permit.sol";

import {SiloERC20} from "./SiloERC20.sol";
import {EIP712Lib} from "./lib/EIP712Lib.sol";
import {NoncesLib} from "./lib/NoncesLib.sol";
import {ERC20PermitLib} from "./lib/ERC20PermitLib.sol";

/**
 * @dev Implementation of the ERC-20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[ERC-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC-20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on `{IERC20-approve}`, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
abstract contract SiloERC20Permit is SiloERC20, IERC20Permit {
    /**
     * @inheritdoc IERC20Permit
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        ERC20PermitLib.permit(owner, spender, value, deadline, v, r, s);
    }

    /**
     * @inheritdoc IERC20Permit
     */
    function nonces(address owner) public view virtual returns (uint256) {
        return NoncesLib.nonces(owner);
    }

    function eip712Domain()
        public
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        return EIP712Lib.eip712Domain();
    }

    /**
     * @inheritdoc IERC20Permit
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
        return EIP712Lib._domainSeparatorV4();
    }
}
