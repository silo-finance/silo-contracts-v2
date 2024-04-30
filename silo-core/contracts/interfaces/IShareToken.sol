// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";

import {ISilo} from "../interfaces/ISilo.sol";

interface IShareToken is IERC20Metadata {
    struct HookSetup {
        /// @param this is the same as in siloConfig
        address hookReceiver;
        /// @param hooks bitmap
        uint24 hooksBefore;
        /// @param hooks bitmap
        uint24 hooksAfter;
        /// @param tokenType must be one of this hooks values: COLLATERAL_TOKEN, PROTECTED_TOKEN, DEBT_TOKEN
        uint24 tokenType;
    }

    /// @notice Emitted every time receiver is notified about token transfer
    /// @param notificationReceiver receiver address
    /// @param success false if TX reverted on `notificationReceiver` side, otherwise true
    event NotificationSent(address indexed notificationReceiver, bool success);

    error AlreadyInitialized();
    error Forbidden();
    error OnlySilo();
    error OnlySiloConfig();
    error OwnerIsZero();
    error RecipientIsZero();
    error ShareTransferNotAllowed();
    error AmountExceedsAllowance();
    error RecipientNotSolventAfterTransfer();
    error SenderNotSolventAfterTransfer();

    /// @param _silo Silo address for which tokens was deployed
    function initialize(ISilo _silo) external;

    /// @notice method for SiloConfig to synchronize hooks
    /// @param _hookReceiver address that will get a callback on mint, burn and transfer of the token
    /// @param _hooksBefore hooks bitmap to trigger hooks BEFORE action
    /// @param _hooksAfter hooks bitmap to trigger hooks AFTER action
    /// @param _tokenType must be one of this hooks values: COLLATERAL_TOKEN, PROTECTED_TOKEN, DEBT_TOKEN
    function synchronizeHooks(address _hookReceiver, uint24 _hooksBefore, uint24 _hooksAfter, uint24 _tokenType)
        external;

    /// @notice Mint method for Silo to create debt
    /// @param _owner wallet for which to mint token
    /// @param _spender wallet that asks for mint
    /// @param _amount amount of token to be minted
    function mint(address _owner, address _spender, uint256 _amount) external;

    /// @notice Burn method for Silo to close debt
    /// @param _owner wallet for which to burn token
    /// @param _spender wallet that asks for burn
    /// @param _amount amount of token to be burned
    function burn(address _owner, address _spender, uint256 _amount) external;

    /// @notice Transfer method for Silo, it is required for ERC4626 standard and liquidation process
    /// @param _owner wallet from which we transfering tokens
    /// @param _recipient wallet that will get tokens
    /// @param _amount amount of token to transfer
    function forwardTransfer(address _owner, address _recipient, uint256 _amount) external;

    /// @notice TransferFrom method for Silo, it is requried for ERC4626 standard
    /// @param _spender wallet that initiates the transfer
    /// @param _owner wallet from which we transfering tokens
    /// @param _recipient wallet that will get tokens
    /// @param _amount amount of token to transfer
    function forwardTransferFrom(address _spender, address _owner, address _recipient, uint256 _amount) external;

    /// @notice Approve method for Silo, it is requried for ERC4626 standard
    /// @param _owner wallet which approves spender
    /// @param _spender wallet will spend the token
    /// @param _amount amount of token to spend
    function forwardApprove(address _owner, address _spender, uint256 _amount) external;

    /// @dev Returns the amount of tokens owned by `account`.
    /// @param _account address for which to return data
    /// @return balance of the _account
    /// @return totalSupply total supply of the token
    function balanceOfAndTotalSupply(address _account) external view returns (uint256 balance, uint256 totalSupply);

    /// @notice Returns silo address for which token was deployed
    /// @return silo address
    function silo() external view returns (ISilo silo);

    function hookSetup() external view returns (HookSetup memory);
}
