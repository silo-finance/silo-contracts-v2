// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {InterestRateModelV2Config} from "silo-core/contracts/interestRateModel/InterestRateModelV2Config.sol";
import {IInterestRateModelV2} from "silo-core/contracts/interfaces/IInterestRateModelV2.sol";

contract InterestRateModelV2ConfigHarness is InterestRateModelV2Config {
    constructor(IInterestRateModelV2.Config memory _config) InterestRateModelV2Config(_config) {}

    function uopt() external view returns (int256 _uopt) {
        _uopt = _UOPT;
    }

    function ucrit() external view returns (int256 _ucrit) {
        _ucrit = _UCRIT;
    }

    function ulow() external view returns (int256 _ulow) {
        _ulow = _ULOW;
    }

    function ki() external view returns (int256 _ki) {
        _ki = _KI;
    }

    function kcrit() external view returns (int256 _kcrit) {
        _kcrit = _KCRIT;
    }

    function klow() external view returns (int256 _klow) {
        _klow = _KLOW;
    }

    function klin() external view returns (int256 _klin) {
        _klin = _KLIN;
    }

    function beta() external view returns (int256 _beta) {
        _beta = _BETA;
    }

    function ri() external view returns (int256 _ri) {
        _ri = _RI;
    }

    function Tcrit() external view returns (int256 _Tcrit) {
        _Tcrit = _TCRIT;
    }
}
