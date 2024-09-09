// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {SiloDeployments} from "silo-core/deploy/silo/SiloDeployments.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

abstract contract GaugeDeployScript is Script {
    bytes32 constant internal _TYPE_SHARE_P_TOKEN = keccak256(abi.encodePacked("protectedShareToken"));
    bytes32 constant internal _TYPE_SHARE_D_TOKEN = keccak256(abi.encodePacked("debtShareToken"));
    bytes32 constant internal _TYPE_SHARE_C_TOKEN = keccak256(abi.encodePacked("collateralShareToken"));

    error InvalidSiloAsset();
    error UnsupportedShareTokenType();

    function _resolveSiloHookReceiver(
        string memory _siloConfigKey,
        string memory _assetKey,
        string memory _token
    ) internal returns(address hookReceiver) {
        address siloAsset = AddrLib.getAddress(_assetKey);

        ISiloConfig siloConfig = ISiloConfig(SiloDeployments.get(ChainsLib.chainAlias(), _siloConfigKey));

        (address silo0, address silo1) = siloConfig.getSilos();

        address silo0Asset = siloConfig.getAssetForSilo(silo0);
        address silo1Asset = siloConfig.getAssetForSilo(silo1);

        if (silo0Asset == siloAsset) {
            hookReceiver = _getHookReceiver(siloConfig, silo0, _token);
        } else if (silo1Asset == siloAsset) {
            hookReceiver = _getHookReceiver(siloConfig, silo1, _token);
        } else {
            revert InvalidSiloAsset();
        }
    }

    function _getHookReceiver(
        ISiloConfig _siloConfig,
        address _silo,
        string memory _token
    ) internal view returns (address hookReceiver) {
        bytes32 tokenType = keccak256(abi.encodePacked(_token));

        address protectedShareToken;
        address collateralShareToken;
        address debtShareToken;

        (protectedShareToken, collateralShareToken, debtShareToken) = _siloConfig.getShareTokens(_silo);

        address token;

        if (_TYPE_SHARE_P_TOKEN == tokenType) {
            token = protectedShareToken;
        } else if (_TYPE_SHARE_D_TOKEN == tokenType) {
            token = debtShareToken;
        } else if (_TYPE_SHARE_C_TOKEN == tokenType) {
            token = collateralShareToken;
        } else {
            revert UnsupportedShareTokenType();
        }

        hookReceiver = IShareToken(token).hookSetup().hookReceiver;
    }
}
