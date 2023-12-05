// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {SiloDeployments} from "silo-core/deploy/silo/SiloDeployments.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {ILiquidityGaugeFactory} from "ve-silo/contracts/gauges/interfaces/ILiquidityGaugeFactory.sol";
import {LiquidityGagugesDeployments} from "./LiquidityGagugesDeployments.sol";

/**
Supported tokens: protectedShareToken | collateralShareToken | debtShareToken
MAX_RELATIVE_WEIGHT_CAP = 10 ** 18

FOUNDRY_PROFILE=ve-silo \
    SILO=ETH-USDC_UniswapV3_Silo \
    ASSET=USDC \
    TOKEN=protectedShareToken \
    RELATIVE_WEIGHT_CAP=0 \
    forge script ve-silo/deploy/gauges/liquidity-gauge/LiquidityGaugeDeployer.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract LiquidityGaugeDeployer is Script {
    uint256 constant internal _MAX_RELATIVE_WEIGHT_CAP = 10 ** 18;

    bytes32 constant internal _TYPE_SHARE_P_TOKEN = keccak256(abi.encodePacked("protectedShareToken"));
    bytes32 constant internal _TYPE_SHARE_D_TOKEN = keccak256(abi.encodePacked("debtShareToken"));
    bytes32 constant internal _TYPE_SHARE_C_TOKEN = keccak256(abi.encodePacked("collateralShareToken"));

    function run() public returns (address gauge) {
        string memory chainAlias = ChainsLib.chainAlias();

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        uint256 relativeWeightCap = vm.envUint("RELATIVE_WEIGHT_CAP");

        ILiquidityGaugeFactory factory = ILiquidityGaugeFactory(
            VeSiloDeployments.get(
                VeSiloContracts.LIQUIDITY_GAUGE_FACTORY,
                chainAlias;
            )
        );

        address hookReceiver = _resolveSiloHookReceiver();

        vm.startBroadcast(deployerPrivateKey);
        gauge = factory.create(relativeWeightCap, hookReceiver);
        vm.stopBroadcast();

        LiquidityGagugesDeployments.save(
            chainAlias,
            vm.envString("SILO"),
            vm.envString("ASSET"),
            vm.envString("TOKEN"),
            gauge
        );
    }

    function _resolveSiloHookReceiver() internal returns(address hookReceiver) {
        string memory siloConfigKey = vm.envString("SILO");
        string memory assetKey = vm.envString("ASSET");

        address siloAsset = AddrLib.getAddress(assetKey);

        ISiloConfig siloConfig = ISiloConfig(SiloDeployments.get(ChainsLib.chainAlias(), siloConfigKey));

        (address silo0, address silo1) = siloConfig.getSilos();

        address silo0Asset = siloConfig.getAssetForSilo(silo0);
        address silo1Asset = siloConfig.getAssetForSilo(silo1);

        if (silo0Asset == siloAsset) {
            hookReceiver = _getHookReceiver(siloConfig, silo0);
        } else if (silo1Asset == siloAsset) {
            hookReceiver = _getHookReceiver(siloConfig, silo1);
        } else {
            revert("Invalid silo asset");
        }
    }

    function _getHookReceiver(ISiloConfig _siloConfig, address _silo) internal view returns (address hookReceiver) {
        bytes32 tokenType = keccak256(abi.encodePacked(vm.envString("TOKEN")));

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
            revert("Unsupported share token type");
        }

        hookReceiver = IShareToken(token).hookReceiver();
    }
}
