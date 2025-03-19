// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Strings} from "openzeppelin5/utils/Strings.sol";
import {TokenHelper} from "silo-core/contracts/lib/TokenHelper.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {InterestRateModelConfigData} from "silo-core/deploy/input-readers/InterestRateModelConfigData.sol";
import {InterestRateModelV2, IInterestRateModelV2} from "silo-core/contracts/interestRateModel/InterestRateModelV2.sol";
import {IInterestRateModelV2Config} from "silo-core/contracts/interfaces/IInterestRateModelV2Config.sol";

library Utils {
    address constant internal _OLD_SILO_VIRTUAL_ASSET_8 = 0xad525F341368AA80093672278234ad364EFcAf0A;

    function findIrmName(ISiloConfig.ConfigData memory _configData)
        internal
        returns (string memory configName, bool success)
    {
        InterestRateModelConfigData.ConfigData[] memory allModels =
            (new InterestRateModelConfigData()).getAllConfigs();

        IInterestRateModelV2Config irmV2Config =
            InterestRateModelV2(_configData.interestRateModel).irmConfig();

        IInterestRateModelV2.Config memory irmConfig = irmV2Config.getConfig();

        uint i;

        for (; i < allModels.length; i++) {
            bool configIsMatching = allModels[i].config.uopt == irmConfig.uopt &&
                allModels[i].config.ucrit == irmConfig.ucrit &&
                allModels[i].config.ulow == irmConfig.ulow &&
                allModels[i].config.ki == irmConfig.ki &&
                allModels[i].config.kcrit == irmConfig.kcrit &&
                allModels[i].config.klow == irmConfig.klow &&
                allModels[i].config.klin == irmConfig.klin &&
                allModels[i].config.beta == irmConfig.beta &&
                allModels[i].config.ri == irmConfig.ri &&
                allModels[i].config.Tcrit == irmConfig.Tcrit;

            if (configIsMatching) {
                break;
            }
        }

        if (i != allModels.length) {
            configName = allModels[i].name;
            success = true;
        }
    }

    function quote(ISiloOracle _oracle, address _baseToken, uint256 _amount)
        internal
        view
        returns (bool success, uint256 price)
    {
        try _oracle.quote(_amount, _baseToken) returns (uint256 priceFromOracle) {
            success = true;
            price = priceFromOracle;
        } catch {}
    }

    /// @dev approximate representation of a past unix timestamp in human readable format.
    function timestampFromNowDescription(uint256 _time) internal view returns (string memory description) {
        uint256 timeDiff = block.timestamp - _time;

        if (timeDiff < 1 minutes) {
            return string.concat(Strings.toString(timeDiff), " seconds ago");
        } else if (timeDiff < 1 hours) {
            return string.concat("approx. ", Strings.toString(timeDiff / 1 minutes), " minutes ago");
        } else if (timeDiff <= 72 hours) {
            return string.concat("approx. ", Strings.toString(timeDiff / (1 hours)), " hours ago");
        } else {
            return string.concat("approx. ", Strings.toString(timeDiff / (1 days)), " days ago");
        }
    }

    function tryGetTokenDecimals(address _token) internal view returns (uint8 decimals) {
        return uint8(TokenHelper.assertAndGetDecimals(_token));
    }

    function tryGetTokenSymbol(address _token) internal view returns (string memory) {
        if (_token == _OLD_SILO_VIRTUAL_ASSET_8) {
            return "Old SiloVirtualAsset8Decimals";
        }

        return TokenHelper.symbol(_token);
    }

    function tryGetTokenName(address _token) internal view returns (string memory) {
        if (_token == _OLD_SILO_VIRTUAL_ASSET_8) {
            return "Old SiloVirtualAsset8Decimals";
        }

        try IERC20Metadata(_token).name() returns (string memory name) {
            return name;
        } catch {
            return "Name reverted";
        }
    }
}
