// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {StdStorage, stdStorage} from "forge-std/StdStorage.sol";

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";
import {Script} from "forge-std/Script.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {IExtendedOwnable} from "ve-silo/contracts/access/IExtendedOwnable.sol";

import {IChainlinkPriceFeedLike} from "ve-silo/test/gauges/interfaces/IChainlinkPriceFeedLike.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/milo-ccip-test/scripts/ccip-helpers/UpdateChainlinkPricesArb.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract UpdateChainlinkPricesArb is Script {
    using stdStorage for StdStorage;

    address internal constant _OWNER = 0x8a89770722c84B60cE02989Aedb22Ac4791F8C7f;
    uint64 internal constant _DESTINATION_CHAIN = 3734403246176062136; // Optimism
    address internal constant _CHAINLINK_PRICE_FEED = 0x13015e4E6f839E1Aa1016DF521ea458ecA20438c;
    address internal constant _LINK = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
    address internal constant _WSTLINK = 0x3106E2e148525b3DB36795b04691D444c24972fB;
    address internal constant _WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    function run() external {
        IChainlinkPriceFeedLike.TokenPriceUpdate[] memory tokenPrices =
            new IChainlinkPriceFeedLike.TokenPriceUpdate[](3);

        tokenPrices[0] = IChainlinkPriceFeedLike.TokenPriceUpdate({
            sourceToken: _LINK,
            usdPerToken: 17352748070000000000 // $17.35
        });

        tokenPrices[1] = IChainlinkPriceFeedLike.TokenPriceUpdate({
            sourceToken: _WSTLINK,
            usdPerToken: 17352748070000000000 // $17.35
        });

        tokenPrices[2] = IChainlinkPriceFeedLike.TokenPriceUpdate({
            sourceToken: _WETH,
            usdPerToken: 3539638400000000000000 // $3539.64
        });

        IChainlinkPriceFeedLike.GasPriceUpdate[] memory gasPrices = new IChainlinkPriceFeedLike.GasPriceUpdate[](1);
        gasPrices[0] = IChainlinkPriceFeedLike.GasPriceUpdate({
            destChainSelector: _DESTINATION_CHAIN,
            usdPerUnitGas: 106827130381460 // $0.00010682713038146
        });

        IChainlinkPriceFeedLike.PriceUpdates memory priceUpdates = IChainlinkPriceFeedLike.PriceUpdates({
            tokenPriceUpdates: tokenPrices,
            gasPriceUpdates: gasPrices
        });

        vm.prank(_OWNER);
        IChainlinkPriceFeedLike(_CHAINLINK_PRICE_FEED).updatePrices(priceUpdates);
    }
}
