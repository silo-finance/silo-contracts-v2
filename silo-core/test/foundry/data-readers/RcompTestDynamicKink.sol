// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {IDynamicKinkModelV1} from "../../../contracts/interfaces/IDynamicKinkModelV1.sol";

contract RcompTestDynamicKink is Test {
    // must be in alphabetic order
    struct InputRcomp {
        int256 currentTime;
        int256 lastSlope;
        int256 lastTransactionTime;
        int256 lastUtilization;
        int256 totalBorrowAmount;
        int256 totalDeposits;
    }

    struct ConstantsRcomp {
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

    struct ExpectedRcomp {
        int256 compoundInterest;
        int256 didCap;
        int256 didOverflow;
        int256 newSlope;
    }

    struct DebugRcomp {
        int256 T;
        int256 f;
        int256 k1;
        int256 roc;
        int256 u0;
        int256 x;
        int256 x_checked;
        int256 x_prelim;
    }

    struct RcompData {
        ConstantsRcomp constants;
        DebugRcomp debug;
        ExpectedRcomp expected;
        uint256 id;
        InputRcomp input;
    }

    function _readDataFromJsonRcomp() internal returns (RcompData[] memory data) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/silo-core/test/foundry/data/RcompDynamicKinkv2.json");
        string memory json = vm.readFile(path);

        data = abi.decode(vm.parseJson(json, string(abi.encodePacked("."))), (RcompData[]));

        for (uint i; i < data.length; i++) {
            _printRcomp(data[i]);
        }
    }

    function _printRcomp(RcompData memory _data) internal {
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
        emit log_named_int("compoundInterest", _data.expected.compoundInterest);
        emit log_named_int("didCap", _data.expected.didCap);
        emit log_named_int("didOverflow", _data.expected.didOverflow);
        emit log_named_int("newSlope", _data.expected.newSlope);

        emit log_string("Debug");
        emit log_named_int("T", _data.debug.T);
        emit log_named_int("f", _data.debug.f);
        emit log_named_int("k1", _data.debug.k1);
        emit log_named_int("roc", _data.debug.roc);
        emit log_named_int("u0", _data.debug.u0);
        emit log_named_int("x", _data.debug.x);
        emit log_named_int("x_checked", _data.debug.x_checked);
        emit log_named_int("x_prelim", _data.debug.x_prelim);
    }

    function _toSetupRcomp(RcompData memory _data)
        internal
        pure
        returns (IDynamicKinkModelV1.Setup memory setup, DebugRcomp memory debug)
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

    function _toConfigStructRcomp(RcompData memory _data)
        internal
        pure
        returns (IDynamicKinkModelV1.Config memory cfg)
    {
        (IDynamicKinkModelV1.Setup memory setup,) = _toSetupRcomp(_data);
        cfg = setup.config;
    }
}
