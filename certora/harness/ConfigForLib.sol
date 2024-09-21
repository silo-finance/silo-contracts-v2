// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { ISiloConfig } from "silo-core/contracts/lib/SiloSolvencyLib.sol";

abstract contract ConfigForLib {

    ISiloConfig.ConfigData internal collateralConfig;
    ISiloConfig.ConfigData internal debtConfig;
    ISiloConfig.DebtInfo internal debtInfo;

    function addNumToAddress(address a, uint8 b) external pure returns (address) {
        uint256 num = uint160(a) + uint160(b);
        require (num <= type(uint160).max);
        return address(uint160(num));
    }

    function getTokensOfDebtConfig() external view returns (address,address,address,address) {
        return (
            debtConfig.token,
            debtConfig.protectedShareToken,
            debtConfig.collateralShareToken,
            debtConfig.debtShareToken
        );
    }

    function getTokensOfCollateralConfig() external view returns (address,address,address,address) {
        return (
            collateralConfig.token,
            collateralConfig.protectedShareToken,
            collateralConfig.collateralShareToken,
            collateralConfig.debtShareToken
        );
    }

    function getSiloForCollateralConfig(bool zeroForSilo) external view returns (address) {
        return zeroForSilo ? collateralConfig.silo : collateralConfig.otherSilo;
    }

    function getSiloForDebtConfig(bool zeroForSilo) external view returns (address) {
        return zeroForSilo ? debtConfig.silo : debtConfig.otherSilo;
    }
}
