// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ISilo} from "./ISilo.sol";

interface IFirmVault {
    event Initialized(address indexed _initialOwner, ISilo indexed _firmSilo);

    /// @dev Emitted when free shares are claimed. 
    /// It can happen when the vault is empty and there are still assets left.
    /// First depositor will be the one who recieve free shares.
    /// @param _receiver The receiver of the free shares
    /// @param _shares The number of free shares claimed
    event FreeShares(address indexed _receiver, uint256 _shares);

    error ZeroShares();
    error ZeroAssets();
    error SelfTransferNotAllowed();
    error ZeroTransfer();
    error OwnerZero();
    error AddressZero();
    error AlreadyInitialized();

    /// @dev Initializes the firm vault
    /// @param _initialOwner The initial owner of the firm vault
    /// @param _firmSilo The firm silo to use for the firm vault
    function initialize(address _initialOwner, ISilo _firmSilo) external;
}
