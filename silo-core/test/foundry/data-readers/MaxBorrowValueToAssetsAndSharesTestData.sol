// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {SiloMathLib} from "silo-core/contracts/lib/SiloMathLib.sol";

contract MaxBorrowValueToAssetsAndSharesTestData {
    struct Input {
        uint256 maxBorrowValue;
        address debtToken;
        bool oracleSet;
        uint256 debtOracleQuote;
        uint256 totalDebtAssets;
        uint256 totalDebtShares;
    }

    struct Output {
        uint256 assets;
        uint256 shares;
    }

    struct MBVData {
        string name;
        Input input;
        Output output;
    }

    address immutable debtToken;

    MBVData[] allData;

    constructor(address _debtToken) {
        debtToken = _debtToken;
    }

    function getData() external returns (MBVData[] memory data) {
        uint256 i;

        i = _init("all zeros");

        i = _init("no borrow yet");
        allData[i].input.maxBorrowValue = 1;
        allData[i].output.assets = 1;
        allData[i].output.shares = 1;

        i = _init("no borrow yet case2");
        allData[i].input.maxBorrowValue = 100;
        allData[i].output.shares = 100;
        allData[i].output.assets = 100;

        i = _init("with some debt, 1value=1assets");
        allData[i].input.maxBorrowValue = 100;
        allData[i].input.totalDebtShares = 9;
        allData[i].input.totalDebtAssets = 9;
        allData[i].output.shares = 100;
        allData[i].output.assets = 100;

        i = _init("has some debt, 1value=0.5assets");
        allData[i].input.maxBorrowValue = 100;
        allData[i].input.totalDebtShares = 18;
        allData[i].input.totalDebtAssets = 9;
        allData[i].output.shares = 200;
        allData[i].output.assets = 100; // for no oracle, value == assets, so maxBorrowValue = 100 => 100 assets

        i = _init("has some debt, 1value=2assets");
        allData[i].input.maxBorrowValue = 5e18;
        allData[i].input.totalDebtShares = 400e18;
        allData[i].input.totalDebtAssets = 200e18;
        allData[i].output.shares = (5e18 * 2) * 2;
        allData[i].output.assets = (5e18 * 2);

        return allData;
    }

    function _init(string memory _name) private returns (uint256 i) {
        i = allData.length;
        allData.push();

        allData[i].name = string(abi.encodePacked("#", toString(i), " ", _name));

        allData[i].input.debtToken = debtToken;
    }

    function _clone(MBVData memory _src) private pure returns (MBVData memory dst) {
        dst.input = Input({
            maxBorrowValue: _src.input.maxBorrowValue,
            debtToken: _src.input.debtToken,
            oracleSet: _src.input.oracleSet,
            debtOracleQuote: _src.input.debtOracleQuote,
            totalDebtAssets: _src.input.totalDebtAssets,
            totalDebtShares: _src.input.totalDebtShares
        });
        dst.output = Output({
            assets: _src.output.assets,
            shares: _src.output.shares
        });
    }

    function toString(uint256 _i) internal pure returns (string memory str) {
        if (_i == 0) return "0";

        while (_i != 0) {
            uint256 r = _i % 10;
            str = string(abi.encodePacked(str, r + 48));
            _i /= 10;
        }
    }
}
