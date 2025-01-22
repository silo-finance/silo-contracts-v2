import {INotificationReceiver} from "silo-vaults/contracts/interfaces/INotificationReceiver.sol";

contract NotificationReceiver is INotificationReceiver {
    /// @notice Called after a token transfer.
    /// @dev Notifies the solution about the token transfer.
    /// @param _sender address empty on mint
    /// @param _senderBalance uint256 sender balance AFTER token transfer
    /// @param _recipient address empty on burn
    /// @param _recipientBalance uint256 recipient balance AFTER token transfer
    /// @param _totalSupply uint256 totalSupply AFTER token transfer
    /// @param _amount uint256 transfer amount
    function afterTokenTransfer(
        address _sender,
        uint256 _senderBalance,
        address _recipient,
        uint256 _recipientBalance,
        uint256 _totalSupply,
        uint256 _amount
    ) public {
        // ...
    }
}