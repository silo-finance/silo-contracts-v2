// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable1and2Step} from "common/utils/Ownable1and2Step.sol";

contract Whitelist is Ownable1and2Step {
    bool public whitelistEnabled;

    mapping(address account => bool isWhitelisted) public isWhitelisted;

    event Whitelisted(address indexed account, bool isWhitelisted);
    event WhitelistEnabled(bool whitelistEnabled);

    error NotWhitelisted();
    error WhitelistDidNotChanged();
    error NoChange();

    modifier onlyWhitelisted(address _account) {
        if (whitelistEnabled) {
            require(isWhitelisted(_account), NotWhitelisted());
        }

        _;
    }

    constructor(address _initialOwner) Ownable1and2Step(_initialOwner) {}

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