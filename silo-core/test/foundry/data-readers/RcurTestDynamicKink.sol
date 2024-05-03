// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {IDynamicKinkModelV1} from "../../../contracts/interfaces/IDynamicKinkModelV1.sol";

contract RcurTestDynamicKink is Test {
    // must be in alphabetic order
    struct InputRcur {
        int256 currentTime;
        int256 lastSlope;
        int256 lastTransactionTime;
        int256 lastUtilization;
        int256 totalBorrowAmount;
        int256 totalDeposits;
    }

    struct ConstantsRcur {
        int256 alpha;
        int256 c1;
        int256 c2;
        int256 cminus;
        int256 cplus;
        int256 dmax;
        int256 kmax;
        int256 kmin;
        int256 rmin;
        int256 u1;
        int256 u2;
        int256 ucrit;
        int256 ulow;
    }

    struct ExpectedRcur {
        int256 currentAnnualInterest;
        int256 didCap;
        int256 didOverflow;
    }

    struct DebugRcur {
        int256 T;
        int256 k;
        int256 r;
        int256 rcur;
        int256 u0;
    }

    struct RcurData {
        ConstantsRcur constants;
        DebugRcur debug;
        ExpectedRcur expected;
        uint256 id;
        InputRcur input;
    }

    function _readDataFromJsonRcur() internal returns (RcurData[] memory data) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/silo-core/test/foundry/data/RcurDynamicKinkv7.json");
        string memory json = vm.readFile(path);

        data = abi.decode(vm.parseJson(json, string(abi.encodePacked("."))), (RcurData[]));
    }

    function _printRcur(RcurData memory _data) internal {
        emit log_named_uint("ID#", _data.id);

        emit log_string("INPUT");
        emit log_named_int("currentTime", _data.input.currentTime);
        emit log_named_int("lastSlope", _data.input.lastSlope);
        emit log_named_int("lastTransactionTime", _data.input.lastTransactionTime);
        emit log_named_int("lastUtilization", _data.input.lastUtilization);
        emit log_named_int("totalBorrowAmount", _data.input.totalBorrowAmount);
        emit log_named_int("totalDeposits", _data.input.totalDeposits);


        emit log_string("Constants");
        emit log_named_int("alpha", _data.constants.alpha);
        emit log_named_int("c1", _data.constants.c1);
        emit log_named_int("c2", _data.constants.c2);
        emit log_named_int("cminus", _data.constants.cminus);
        emit log_named_int("cplus", _data.constants.cplus);
        emit log_named_int("dmax", _data.constants.dmax);
        emit log_named_int("kmax", _data.constants.kmax);
        emit log_named_int("kmin", _data.constants.kmin);
        emit log_named_int("rmin", _data.constants.rmin);
        emit log_named_int("u1", _data.constants.u1);
        emit log_named_int("u2", _data.constants.u2);
        emit log_named_int("ucrit", _data.constants.ucrit);
        emit log_named_int("ulow", _data.constants.ulow);

        emit log_string("Expected");
        emit log_named_int("currentAnnualInterest", _data.expected.currentAnnualInterest);
        emit log_named_int("didCap", _data.expected.didCap);
        emit log_named_int("didOverflow", _data.expected.didOverflow);

        emit log_string("Debug");
        emit log_named_int("T", _data.debug.T);
        emit log_named_int("k", _data.debug.k);
        emit log_named_int("r", _data.debug.r);
        emit log_named_int("rcur", _data.debug.rcur);
        emit log_named_int("u0", _data.debug.u0);
    }

    function _toSetupRcur(RcurData memory _data)
        internal
        pure
        returns (IDynamicKinkModelV1.Setup memory setup, DebugRcur memory debug)
    {

        setup.config.alpha = _data.constants.alpha;
        setup.config.c1 = _data.constants.c1;
        setup.config.c2 = _data.constants.c2;
        setup.config.cminus = _data.constants.cminus;
        setup.config.cplus = _data.constants.cplus;
        setup.config.dmax = _data.constants.dmax;
        setup.config.kmax = _data.constants.kmax;
        setup.config.kmin = _data.constants.kmin;
        setup.config.rmin = _data.constants.rmin;
        setup.config.u1 = _data.constants.u1;
        setup.config.u2 = _data.constants.u2;
        setup.config.ucrit = _data.constants.ucrit;
        setup.config.ulow = _data.constants.ulow;

        setup.k = _data.input.lastSlope;
    }

    function _toConfigStructRcur(RcurData memory _data)
        internal
        pure
        returns (IDynamicKinkModelV1.Config memory cfg)
    {
        (IDynamicKinkModelV1.Setup memory setup,) = _toSetupRcur(_data);
        cfg = setup.config;
    }
}
