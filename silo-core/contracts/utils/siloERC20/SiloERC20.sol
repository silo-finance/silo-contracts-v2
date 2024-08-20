// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20Errors} from "openzeppelin5/interfaces/draft-IERC6093.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";

import {ERC20Lib} from "./lib/ERC20Lib.sol";

/**
 * @notice copy of {ERC20}, except:
 * - constructor removed
 * - added `virtual` to all methods
 * - added `emitEvents()` method
 * - added _beforeTokenTransfer, _afterTokenTransfer
 * - disallow zero transfer
 *
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC-20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the ERC may not emit
 * these events, as it isn't required by the specification.
 */
abstract contract SiloERC20 is IERC20, IERC20Metadata, IERC20Errors {
    error ZeroTransfer();

    /**
     * @dev flag that tels contract, if it should emit events
     */
    function emitEvents() public pure virtual returns (bool) {
        return true;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return ERC20Lib.name();
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return ERC20Lib.symbol();
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        return ERC20Lib.totalSupply();
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        return ERC20Lib.balanceOf(account);
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `value`.
     */
    function transfer(address to, uint256 value) public virtual returns (bool result) {
        result = _transfer(msg.sender, to, value);
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return ERC20Lib.allowance(owner, spender);
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
    function approve(address spender, uint256 value) public virtual returns (bool result) {
        return _approve(msg.sender, spender, value);
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the ERC. See the note at the beginning of {ERC20}.
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
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool result) {
        if (value == 0) revert ZeroTransfer();

        _beforeTokenTransfer(from, to, value);

        result = ERC20Lib.transferFrom(from, to, value);

        _afterTokenTransfer(from, to, value);

        if (emitEvents()) {
            emit IERC20.Transfer(from, to, value);
        }
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
    function _transfer(address from, address to, uint256 value) internal virtual returns (bool result) {
        if (value == 0) revert ZeroTransfer();

        _beforeTokenTransfer(from, to, value);

        ERC20Lib._transfer(from, to, value);

        _afterTokenTransfer(from, to, value);

        if (emitEvents()) {
            emit IERC20.Transfer(from, to, value);
        }

        result = true;
    }

    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     */
    function _update(address from, address to, uint256 value) internal virtual {
        if (value == 0) revert ZeroTransfer();

        _beforeTokenTransfer(from, to, value);

        ERC20Lib._update(from, to, value);

        _afterTokenTransfer(from, to, value);

        if (emitEvents()) {
            emit IERC20.Transfer(from, to, value);
        }
    }

    /**
     * @dev Creates a `value` amount of tokens and assigns them to `account`, by transferring it from address(0).
     * Relies on the `_update` mechanism
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _mint(address account, uint256 value) internal virtual {
        if (value == 0) revert ZeroTransfer();

        _beforeTokenTransfer(address(0), account, value);

        ERC20Lib._mint(account, value);

        _afterTokenTransfer(address(0), account, value);

        if (emitEvents()) {
            emit IERC20.Transfer(address(0), account, value);
        }
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, lowering the total supply.
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead
     */
    function _burn(address account, uint256 value) internal virtual {
        if (value == 0) revert ZeroTransfer();

        _beforeTokenTransfer(account, address(0), value);

        ERC20Lib._burn(account, value);

        _afterTokenTransfer(account, address(0), value);

        if (emitEvents()) {
            emit IERC20.Transfer(account, address(0), value);
        }
    }

    /**
     * @dev Sets `value` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address owner, address spender, uint256 value) internal virtual returns (bool result) {
        return _approve(owner, spender, value, emitEvents());
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
     * ```
     * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * ```
     *
     * Requirements are the same as {_approve}.
     */
    function _approve(address owner, address spender, uint256 value, bool emitEvent)
        internal
        virtual
        returns (bool result)
    {
        ERC20Lib._approve(owner, spender, value);

        if (emitEvent) {
            emit Approval(owner, spender, value);
        }

        result = true;
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Does not emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        ERC20Lib._spendAllowance(owner, spender, value);
    }

    function _beforeTokenTransfer(address /* _sender */, address /* _recipient */, uint256 /* _amount */)
        internal
        virtual {}

    function _afterTokenTransfer(address /* _sender */, address /* _recipient */, uint256 /* _amount */)
        internal
        virtual {}
}
