// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable1and2Steps} from "common/access/Ownable1and2Steps.sol";

// TODO we could also use roles instead of whitelist, but we still need `whitelistEnabled` logic,
// so idk if it would be beneficial
abstract contract Whitelist is Ownable1and2Steps {
    bool public whitelistEnabled;

    mapping(address account => bool isWhitelisted) public isWhitelisted;

    event Whitelisted(address indexed account, bool isWhitelisted);
    event WhitelistEnabled(bool whitelistEnabled);

    error NotWhitelisted();
    error WhitelistDidNotChanged();
    error NoChange();

    modifier onlyWhitelisted(address _account) {
        if (whitelistEnabled) {
            require(isWhitelisted[_account], NotWhitelisted());
        }

        _;
    }

    constructor(address _initialOwner) Ownable1and2Steps(_initialOwner) {}

    function setWhitelisted(address _account, bool _isWhitelisted) external onlyOwner {
        require(isWhitelisted[_account] != _isWhitelisted, WhitelistDidNotChanged());

        isWhitelisted[_account] = _isWhitelisted;
        emit Whitelisted(_account, _isWhitelisted);
    }

    function setWhitelistEnabled(bool _whitelistEnabled) external onlyOwner {
        require(whitelistEnabled != _whitelistEnabled, NoChange());

        whitelistEnabled = _whitelistEnabled;
        emit WhitelistEnabled(_whitelistEnabled);
    }
}