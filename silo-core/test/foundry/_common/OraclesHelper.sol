// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {OracleMock} from "../_mocks/OracleMock.sol";

abstract contract OraclesHelper is Test {
    address immutable COLLATERAL_ASSET;
    address immutable DEBT_ASSET;

    address immutable COLLATERAL_ORACLE;
    address immutable DEBT_ORACLE;

    OracleMock collateralOracle;
    OracleMock debtOracle;

    constructor() {
        COLLATERAL_ASSET = makeAddr("COLLATERAL_ASSET");
        DEBT_ASSET = makeAddr("DEBT_ASSET");
        COLLATERAL_ORACLE = makeAddr("COLLATERAL_ORACLE");
        DEBT_ORACLE = makeAddr("DEBT_ORACLE");

        collateralOracle = new OracleMock(COLLATERAL_ORACLE);
        debtOracle = new OracleMock(DEBT_ORACLE);
    }
}
