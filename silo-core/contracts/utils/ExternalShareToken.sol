// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ShareToken} from "./ShareToken.sol";
import {ISilo, IShareToken} from "../interfaces/IShareToken.sol";
import {ISiloConfig} from "../SiloConfig.sol";

abstract contract ExternalShareToken is ShareToken {
    /// @custom:storage-location erc7201:silo.exteranalShareToken.storage
    struct ExternalShareTokenStorage {
        /// @notice Silo address for which tokens was deployed
        ISilo silo;
        /// @notice cached silo config address
        ISiloConfig siloConfig;
    }

    // keccak256(abi.encode(uint256(keccak256("silo.exteranalShareToken.storage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant ExternalShareTokenStorageLocation =
        0xf3388f20773fee18391259c866bc8cc07f49a4551491e986006d82a5c283c900;
    
    /// @inheritdoc IShareToken
    function synchronizeHooks(uint24 _hooksBefore, uint24 _hooksAfter) external {
        _onlySilo();

        ShareTokenStorage storage $ = _getShareTokenStorage();

        $.hookSetup.hooksBefore = _hooksBefore;
        $.hookSetup.hooksAfter = _hooksAfter;
    }

    function silo() external view returns (ISilo) {
        return _getExternalShareTokenStorage().silo;
    }

    function _getExternalShareTokenStorage() internal pure returns (ExternalShareTokenStorage storage $) {
        assembly {
            $.slot := ExternalShareTokenStorageLocation
        }
    }

    function __ExternalShareToken_init(ISilo _currentSilo, address _hookReceiver, uint24 _tokenType) internal virtual {
        __ShareToken_init(_hookReceiver, _tokenType);

        _getExternalShareTokenStorage().silo = _currentSilo;
        _getExternalShareTokenStorage().siloConfig = _currentSilo.config();
    }

    function _onlySilo() internal view override {
        if (msg.sender != address(_getExternalShareTokenStorage().silo)) revert OnlySilo();
    }

    function _getSiloConfig() internal view override returns (ISiloConfig) {
        return _getExternalShareTokenStorage().siloConfig;
    }

    function _silo() internal view override returns (ISilo) {
        return _getExternalShareTokenStorage().silo;
    }
}
