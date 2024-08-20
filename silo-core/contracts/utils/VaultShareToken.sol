// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {SiloStorageLib} from "silo-core/contracts/lib/SiloStorageLib.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ShareToken} from "./ShareToken.sol";

contract VaultShareToken is ShareToken {
    function initialize(ISilo, address _hookReceiver, uint24 _tokenType) external {
        __ShareToken_init(_hookReceiver, _tokenType);
    }

    /// @inheritdoc IShareToken
    function mint(address _owner, address, uint256 _amount) external virtual override {
        _mint(_owner, _amount);
    }

    /// @inheritdoc IShareToken
    function burn(address _owner, address _spender, uint256 _amount) external virtual {
        if (_owner != _spender) _spendAllowance(_owner, _spender, _amount);
        _burn(_owner, _amount);
    }

    function synchronizeHooks(uint24, uint24) external {}

    function silo() external view returns (ISilo) {
        return ISilo(address(this));
    }

    function _getSiloConfig() internal view override returns (ISiloConfig) {
        return SiloStorageLib.siloConfig();
    }
}
