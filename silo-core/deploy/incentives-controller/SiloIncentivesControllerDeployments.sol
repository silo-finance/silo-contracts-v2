// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6;

import {KeyValueStorage} from "silo-foundry-utils/key-value/KeyValueStorage.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";

import {TokenHelper} from "silo-core/contracts/lib/TokenHelper.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

library SiloIncentivesControllerDeployments {
    string constant public DEPLOYMENTS_FILE = "silo-core/deploy/incentives-controller/_siloIncentivesControllerDeployments.json";

    error InvalidShareToken();

    function save(
        string memory _chain,
        address _shareToken,
        address _deployed
    ) internal {
        string memory _name = _constructName(_shareToken);

        KeyValueStorage.setAddress(
            DEPLOYMENTS_FILE,
            _chain,
            _name,
            _deployed
        );
    }

    function get(string memory _chain, address _shareToken) internal returns (address) {
        string memory _name = _constructName(_shareToken);

        address shared = AddrLib.getAddress(_name);

        if (shared != address(0)) {
            return shared;
        }

        return KeyValueStorage.getAddress(
            DEPLOYMENTS_FILE,
            _chain,
            _name
        );
    }

    function _constructName(address _shareToken) internal view returns (string memory name) {
        ISiloConfig siloConfig = IShareToken(_shareToken).siloConfig();

        (address silo0, address silo1) = siloConfig.getSilos();

        string memory silo0AssetSymbol;
        string memory silo1AssetSymbol;

        {
            address silo0Asset = ISilo(silo0).asset();
            address silo1Asset = ISilo(silo1).asset();

            silo0AssetSymbol = TokenHelper.symbol(silo0Asset);
            silo1AssetSymbol = TokenHelper.symbol(silo1Asset);
        }
        

        uint256 silo0Id = siloConfig.SILO_ID();

        bool isSilo0 = isSilo0Asset(siloConfig, _shareToken);

        name = string.concat(
            "SIC ",
            silo0AssetSymbol,
            "/",
            silo1AssetSymbol,
            "(",
            VmLib.vm().toString(silo0Id),
            ")",
            " ",
            isSilo0 ? silo0AssetSymbol : silo1AssetSymbol,
            ":",
            _getTokenType(siloConfig, isSilo0 ? silo0 : silo1, _shareToken)
        );
    }

    function isSilo0Asset(ISiloConfig _siloConfig, address _shareToken) internal view returns (bool isSilo0) {
        (address silo0, address silo1) = _siloConfig.getSilos();

        address protectedShareToken;
        address collateralShareToken;
        address debtShareToken;

        (protectedShareToken, collateralShareToken, debtShareToken) = _siloConfig.getShareTokens(silo0);

        isSilo0 = _shareToken == protectedShareToken ||
            _shareToken == collateralShareToken ||
            _shareToken == debtShareToken;

        if (!isSilo0) {
            (protectedShareToken, collateralShareToken, debtShareToken) = _siloConfig.getShareTokens(silo1);

            bool isSilo1 = _shareToken == protectedShareToken ||
                _shareToken == collateralShareToken ||
                _shareToken == debtShareToken;

            require(isSilo1, InvalidShareToken());
        }
    }

    function _getTokenType(
        ISiloConfig _siloConfig,
        address _silo,
        address _shareToken
    ) internal view returns (string memory tokenType) {
        (
            address protectedShareToken,
            address collateralShareToken,
            address debtShareToken
        ) = _siloConfig.getShareTokens(_silo);

        if (_shareToken == collateralShareToken) return "Collateral";
        if (_shareToken == protectedShareToken) return "Protected";
        if (_shareToken == debtShareToken) return "Debt";

        revert InvalidShareToken();
    }
}
