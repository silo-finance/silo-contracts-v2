// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";
import {SignedMath} from "openzeppelin5/utils/math/SignedMath.sol";

import {DynamicKinkModel, IDynamicKinkModel} from "../../../../contracts/interestRateModel/kink/DynamicKinkModel.sol";

import {ISilo} from "../../../../contracts/interfaces/ISilo.sol";

abstract contract KinkCommon {
    // using RandomLib for uint256;

    struct RandomKinkConfig {
        uint64 ulow;
        uint64 u1;
        uint64 u2;
        uint64 ucrit;
        uint64 rmin;
        uint96 kmin;
        uint96 kmax;
        uint96 alpha;
        uint96 cminus;
        uint96 cplus;
        uint96 c1;
        uint96 c2;
        uint96 dmax;
    }

    int256 constant _DP = 10 ** 18;
    int256 public constant UNIVERSAL_LIMIT = 1e9 * _DP;

    DynamicKinkModel irm;
    ISilo.UtilizationData internal _utilizationData;

    function utilizationData() external view returns (ISilo.UtilizationData memory) {
        return _utilizationData;
    }

    function _setUtilizationData(ISilo.UtilizationData memory _data) internal {
        _utilizationData = _data;
    }

    function _isValidConfig(RandomKinkConfig memory _config) 
        internal 
        view 
        returns (bool valid) 
    {
        try irm.verifyConfig(_toConfig(_config)) {
            valid = true;
        } catch {
            valid = false;
        }
    }

    function _isValidConfig(IDynamicKinkModel.Config memory _config) 
        internal 
        view 
        returns (bool valid) 
    {
        try irm.verifyConfig(_config) {
            valid = true;
        } catch {
            valid = false;
        }
    }

    function _toConfig(RandomKinkConfig memory _config) internal pure returns (IDynamicKinkModel.Config memory) {
        return IDynamicKinkModel.Config({
            ulow: SafeCast.toInt256(uint256(_config.ulow)),
            u1: SafeCast.toInt256(uint256(_config.u1)),
            u2: SafeCast.toInt256(uint256(_config.u2)),
            ucrit: SafeCast.toInt256(uint256(_config.ucrit)),
            rmin: SafeCast.toInt256(uint256(_config.rmin)),
            // we need to modulo, because on both sides we have 96 bits,
            // in order not to use vm.assume or require, we bound random value
            kmin: int96(_config.kmin % uint96(type(int96).max)),
            kmax: int96(_config.kmax % uint96(type(int96).max)),
            alpha: SafeCast.toInt256(uint256(_config.alpha)),
            cminus: SafeCast.toInt256(uint256(_config.cminus)),
            cplus: SafeCast.toInt256(uint256(_config.cplus)),
            c1: SafeCast.toInt256(uint256(_config.c1)),
            c2: SafeCast.toInt256(uint256(_config.c2)),
            dmax: SafeCast.toInt256(uint256(_config.dmax))
        });
    }

    function _makeConfigValid(IDynamicKinkModel.Config memory _config) internal pure {
        _config.u1 = _getBetween(_config.u1, 0, _DP);
        _config.u2 = _getBetween(_config.u2, _config.u1, _DP);
        _config.ulow = _getBetween(_config.ulow, 0, _config.u1);
    
        _config.ucrit = _getBetween(_config.ucrit, _config.u2, _DP);
        _config.rmin = _getBetween(_config.rmin, 0, _DP);
        _config.kmin = int96(_getBetween(_config.kmin, 0, UNIVERSAL_LIMIT));
        _config.kmax = int96(_getBetween(_config.kmax, _config.kmin, UNIVERSAL_LIMIT));
        _config.alpha = _getBetween(_config.alpha, 0, UNIVERSAL_LIMIT);
        _config.cminus = _getBetween(_config.cminus, 0, UNIVERSAL_LIMIT);
        _config.cplus = _getBetween(_config.cplus, 0, UNIVERSAL_LIMIT);
        _config.c1 = _getBetween(_config.c1, 0, UNIVERSAL_LIMIT);
        _config.c2 = _getBetween(_config.c2, 0, UNIVERSAL_LIMIT);
        _config.dmax = _getBetween(_config.dmax, _config.c2, UNIVERSAL_LIMIT);
    }

    function _getBetween(int256 _n, int256 _min, int256 _max) internal pure returns (int256) {
        return SignedMath.max(SignedMath.min(_n, _max), _min);
    }

    function _printConfig(IDynamicKinkModel.Config memory _config) internal pure {
        console2.log("-------------------------------- start --------------------------------");
        console2.log("ulow %s", _config.ulow);
        console2.log("u1 %s", _config.u1);
        console2.log("u2 %s", _config.u2);
        console2.log("ucrit %s", _config.ucrit);
        console2.log("rmin %s", _config.rmin);
        console2.log("kmin %s", _config.kmin);
        console2.log("kmax %s", _config.kmax);
        console2.log("alpha %s", _config.alpha);
        console2.log("cminus %s", _config.cminus);
        console2.log("cplus %s", _config.cplus);
        console2.log("c1 %s", _config.c1);
        console2.log("c2 %s", _config.c2);
        console2.log("dmax %s", _config.dmax);
        console2.log("-------------------------------- end --------------------------------");
    }

    function _hashConfig(IDynamicKinkModel.Config memory _config) internal pure returns (bytes32) {
        return keccak256(abi.encode(_config));
    }

    function _defaultConfig() internal pure returns (IDynamicKinkModel.Config memory) {
        return IDynamicKinkModel.Config({
            ulow: 200000000000000000,
            u1: 500000000000000000,
            u2: 700000000000000000,
            ucrit: 600000000000000000,
            rmin: 158549000,
            kmin: 1585490000,
            kmax: 3170980000,
            alpha: 4000000000000000000,
            cminus: 367011,
            cplus: 36701,
            c1: 3670,
            c2: 3670,
            dmax: 7340
        });
    }
}
