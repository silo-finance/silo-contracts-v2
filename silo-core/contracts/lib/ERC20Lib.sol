// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20Errors} from "openzeppelin5/interfaces/draft-IERC6093.sol";

import {ISiloERC20} from "../inerfaces/ISiloERC20.sol";

library ERC20Lib {
//    /**
//     * @dev Returns the name of the token.
//     */
//    function name(ISiloERC20.ERC20Storage storage $) external view returns (string memory) {
//        return $._name;
//    }
//
//    /**
//     * @dev Returns the symbol of the token, usually a shorter version of the
//     * name.
//     */
//    function symbol(ISiloERC20.ERC20Storage storage $) external view returns (string memory) {
//        return $._symbol;
//    }
//
//    /**
//     * @dev Returns the number of decimals used to get its user representation.
//     * For example, if `decimals` equals `2`, a balance of `505` tokens should
//     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
//     *
//     * Tokens usually opt for a value of 18, imitating the relationship between
//     * Ether and Wei. This is the default value returned by this function, unless
//     * it's overridden.
//     *
//     * NOTE: This information is only used for _display_ purposes: it in
//     * no way affects any of the arithmetic of the contract, including
//     * {IERC20-balanceOf} and {IERC20-transfer}.
//     */
//    function decimals() external view returns (uint8) {
//        return 18;
//    }
//
//    /**
//     * @dev See {IERC20-totalSupply}.
//     */
//    function totalSupply(ISiloERC20.ERC20Storage storage $) external view returns (uint256) {
//        return $._totalSupply;
//    }
//
//    /**
//     * @dev See {IERC20-balanceOf}.
//     */
//    function balanceOf(ISiloERC20.ERC20Storage storage $, address account) internal view returns (uint256) {
//        return $._balances[account];
//    }
    
    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `value`.
     */
    function transfer(ISiloERC20.ERC20Storage storage $, address to, uint256 value) public returns (bool) {
        address owner = _msgSender();
        _transfer($, owner, to, value);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(ISiloERC20.ERC20Storage storage $, address owner, address spender)
        public
        view
        returns (uint256)
    {
        return $._allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `value` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(ISiloERC20.ERC20Storage storage $, address spender, uint256 value) public returns (bool) {
        address owner = _msgSender();
        _approve($, owner, spender, value);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Skips emitting an {Approval} event indicating an allowance update. This is not
     * required by the ERC. See {xref-ERC20-_approve-address-address-uint256-bool-}[_approve].
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `value`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     */
    function transferFrom(ISiloERC20.ERC20Storage storage $, address from, address to, uint256 value)
        public
        returns (bool)
    {
        address spender = _msgSender();
        _spendAllowance($, from, spender, value);
        _transfer($, from, to, value);
        return true;
    }

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _transfer(ISiloERC20.ERC20Storage storage $, address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert IERC20Errors.ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert IERC20Errors.ERC20InvalidReceiver(address(0));
        }
        _update($, from, to, value);
    }

    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     */
    function _update(ISiloERC20.ERC20Storage storage $, address from, address to, uint256 value) internal {
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            $._totalSupply += value;
        } else {
            uint256 fromBalance = $._balances[from];
            if (fromBalance < value) {
                revert IERC20Errors.ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                $._balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                $._totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                $._balances[to] += value;
            }
        }

        // emit Transfer(from, to, value);
    }

    /**
     * @dev Creates a `value` amount of tokens and assigns them to `account`, by transferring it from address(0).
     * Relies on the `_update` mechanism
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _mint(ISiloERC20.ERC20Storage storage $, address account, uint256 value) internal {
        if (account == address(0)) {
            revert IERC20Errors.ERC20InvalidReceiver(address(0));
        }
        _update($, address(0), account, value);
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, lowering the total supply.
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead
     */
    function _burn(ISiloERC20.ERC20Storage storage $, address account, uint256 value) internal {
        if (account == address(0)) {
            revert IERC20Errors.ERC20InvalidSender(address(0));
        }
        _update($, account, address(0), value);
    }

    /**
     * @dev Variant of {_approve} with an optional flag to enable or disable the {Approval} event.
     *
     * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
     * `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any
     * `Approval` event during `transferFrom` operations.
     *
     * Anyone who wishes to continue emitting `Approval` events on the`transferFrom` operation can force the flag to
     * true using the following override:
     *
     * ```solidity
     * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * ```
     *
     * Requirements are the same as {_approve}.
     */
    function _approve(ISiloERC20.ERC20Storage storage $, address owner, address spender, uint256 value) internal {
        if (owner == address(0)) {
            revert IERC20Errors.ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert IERC20Errors.ERC20InvalidSpender(address(0));
        }
        $._allowances[owner][spender] = value;
        // emit Approval(owner, spender, value);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     */
    function _spendAllowance(ISiloERC20.ERC20Storage storage $, address owner, address spender, uint256 value)
        internal
    {
        uint256 currentAllowance = allowance($, owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert IERC20Errors.ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve($, owner, spender, currentAllowance - value);
            }
        }
    }
    
    function _msgSender() internal view returns (address) {
        return msg.sender;
    }
}
