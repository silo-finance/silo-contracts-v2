// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import "../interface/ISiloFactory.sol";
import "../interface/IShareToken.sol";
import "../interface/INotificationReceiver.sol";

/// @title ShareToken
/// @notice Implements common interface for Silo tokens representing debt or collateral positions.
/// @custom:security-contact security@silo.finance
abstract contract ShareToken is ERC20Upgradeable, IShareToken {
    /// @dev minimal share amount will give us higher precision for shares calculation,
    /// that way losses caused by division will be reduced to acceptable level
    uint256 public constant MINIMUM_SHARE_AMOUNT = 1e5;

    ISiloFactory public immutable factory;

    /// @notice Silo address for which tokens was deployed
    ISilo public silo;

    /// @notice asset for which this tokens was deployed
    address public asset;

    /// @dev decimals that match the original asset decimals
    uint8 internal _decimals;

    error OnlySilo();
    error MinimumShareRequirement();

    modifier onlySilo() {
        if (msg.sender != address(silo)) revert OnlySilo();

        _;
    }

    /// @dev Token is always deployed for specific Silo and asset
    constructor(ISiloFactory _factory) {
        factory = _factory;
    }

    /// @param _name token name
    /// @param _symbol token symbol
    /// @param _silo Silo address for which tokens was deployed
    /// @param _asset asset for which this tokens was deployed
    function __ShareToken_init(string memory _name, string memory _symbol, ISilo _silo, address _asset)
        internal
        onlyInitializing
    {
        __ERC20_init(_name, _symbol);

        silo = _silo;
        asset = _asset;
    }

    function _afterTokenTransfer(address _sender, address _recipient, uint256 _amount) internal virtual override {
        // report mint/burn or transfer
        _notifyAboutTransfer(_sender, _recipient, _amount);

        // fixing precision error on mint and burn
        if (_isTransfer(_sender, _recipient)) {
            return;
        }

        uint256 total = totalSupply();
        // we require minimum amount to be present from first mint
        // and after burning, we do not allow for small leftover
        if (total != 0 && total < MINIMUM_SHARE_AMOUNT) revert MinimumShareRequirement();
    }

    /// @dev Report token transfer to incentive contract if one is set
    /// @param _from sender
    /// @param _to recipient
    /// @param _amount amount that was transferred
    function _notifyAboutTransfer(address _from, address _to, uint256 _amount) internal {
        address notificationReceiver = factory.getNotificationReceiver(address(this));

        if (notificationReceiver != address(0)) {
            // solhint-disable-next-line avoid-low-level-calls
            (bool success,) = notificationReceiver.call(
                abi.encodeWithSelector(
                    INotificationReceiver.onAfterTransfer.selector, address(this), _from, _to, _amount
                )
            );

            emit NotificationSent(notificationReceiver, success);
        }
    }

    /// @dev checks if operation is "real" transfer
    /// @param _sender sender address
    /// @param _recipient recipient address
    /// @return bool true if operation is real transfer, false if it is mint or burn
    function _isTransfer(address _sender, address _recipient) internal pure returns (bool) {
        // in order this check to be true, is is required to have:
        // require(sender != address(0), "ERC20: transfer from the zero address");
        // require(recipient != address(0), "ERC20: transfer to the zero address");
        // on transfer. ERC20 has them, so we good.
        return _sender != address(0) && _recipient != address(0);
    }
}
