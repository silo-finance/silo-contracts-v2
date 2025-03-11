// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IKeyringChecker} from "silo-core/contracts/interfaces/IKeyringChecker.sol";

contract KeyringCheckerMock is IKeyringChecker {
    mapping(uint256 => mapping(address => bool)) public whitelisted;

    function checkCredential(uint256 policyId, address user) external view returns (bool) {
        return whitelisted[policyId][user];
    }

    function setWhitelisted(uint256 policyId, address user, bool status) external {
        whitelisted[policyId][user] = status;
    }
} 