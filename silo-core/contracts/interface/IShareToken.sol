// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {
    IERC20MetadataUpgradeable
} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {ISilo} from "../interface/ISilo.sol";

interface IShareToken is IERC20MetadataUpgradeable {
    /// @notice Emitted every time receiver is notified about token transfer
    /// @param notificationReceiver receiver address
    /// @param success false if TX reverted on `notificationReceiver` side, otherwise true
    event NotificationSent(address indexed notificationReceiver, bool success);

    error Forbidden();

    /// @param _name token name
    /// @param _symbol token symbol
    /// @param _silo Silo address for which tokens was deployed
    /// @param _asset asset for which this tokens was deployed
    function initialize(string memory _name, string memory _symbol, ISilo _silo, address _asset) external;

    /// @notice Mint method for Silo to create debt position
    /// @param _owner wallet for which to mint token
    /// @param _spender wallet that asks for mint
    /// @param _amount amount of token to be minted
    function mint(address _owner, address _spender, uint256 _amount) external;

    /// @notice Burn method for Silo to close debt position
    /// @param _owner wallet for which to burn token
    /// @param _spender wallet that asks for burn
    /// @param _amount amount of token to be burned
    function burn(address _owner, address _spender, uint256 _amount) external;
}
