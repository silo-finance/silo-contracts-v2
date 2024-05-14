// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

contract MaxBorrowValueToAssetsAndSharesTestData {
    uint256 constant SHARE_TOKEN_OFFSET = 10 ** 0;

    struct Input {
        uint256 maxBorrowValue;
        uint256 borrowerDebtValue;
        address borrower;
        address debtToken;
        address debtShareToken;
        uint256 totalDebtAssets;
        uint256 totalDebtShares;
    }

    struct Mocks {
        uint256 debtTokenDecimals;
        uint256 debtShareTokenBalanceOf;
    }

    struct Output {
        uint256 assets;
        uint256 shares;
    }

    struct MBVData {
        string name;
        Input input;
        Mocks mocks;
        Output output;
    }

    address immutable debtToken;
    address immutable debtShareToken;

    MBVData[] allData;

    constructor(address _debtToken, address _debtShareToken) {
        debtToken = _debtToken;
        debtShareToken = _debtShareToken;
    }

    function getData() external returns (MBVData[] memory data) {
        uint256 i;

        i = _init("all zeros");

        i = _init("borrowerDebtValue=0, no borrow yet");
        allData[i].input.maxBorrowValue = 1;
        allData[i].output.assets = 1;
        allData[i].output.shares = 1 * SHARE_TOKEN_OFFSET;

        i = _init("borrowerDebtValue!=0, has some debt, 1value=1assets");
        allData[i].input.maxBorrowValue = 100;
        allData[i].input.borrowerDebtValue = 9;
        allData[i].input.totalDebtShares = 9 * SHARE_TOKEN_OFFSET;
        allData[i].input.totalDebtAssets = 9;
        allData[i].mocks.debtShareTokenBalanceOf = 9 * SHARE_TOKEN_OFFSET;
        allData[i].output.assets = 100;
        allData[i].output.shares = 100 * SHARE_TOKEN_OFFSET;

        i = _init("borrowerDebtValue!=0, has some debt, 1value=0.5assets");
        allData[i].input.maxBorrowValue = 100;
        allData[i].input.borrowerDebtValue = 18;
        allData[i].input.totalDebtShares = 18 * SHARE_TOKEN_OFFSET;
        allData[i].input.totalDebtAssets = 9;
        allData[i].mocks.debtShareTokenBalanceOf = 18 * SHARE_TOKEN_OFFSET;
        allData[i].output.assets = 50;
        allData[i].output.shares = 100 * SHARE_TOKEN_OFFSET;

        i = _init("borrowerDebtValue!=0, has some debt, 1value=2assets");
        allData[i].input.maxBorrowValue = 5e18;
        allData[i].input.borrowerDebtValue = 0.25e18;
        allData[i].input.totalDebtShares = 400e18 * SHARE_TOKEN_OFFSET;
        allData[i].input.totalDebtAssets = 200e18;
        allData[i].mocks.debtShareTokenBalanceOf = 1e18 * SHARE_TOKEN_OFFSET; // 0.5e18 assets => /2 0.25value
        allData[i].output.assets = 5e18 * 2;
        allData[i].output.shares = 5e18 * 2 * 2 * SHARE_TOKEN_OFFSET;

        return allData;
    }

    function _init(string memory _name) private returns (uint256 i) {
        i = allData.length;
        allData.push();

        allData[i].name = string(abi.encodePacked("#", toString(i), " ", _name));

        allData[i].input.debtToken = debtToken;
        allData[i].input.debtShareToken = debtShareToken;
        allData[i].input.borrower = address(0xbbbbbbbb);

        allData[i].mocks.debtTokenDecimals = 18;
    }

    function _clone(MBVData memory _src) private pure returns (MBVData memory dst) {
        dst.input = Input({
            maxBorrowValue: _src.input.maxBorrowValue,
            borrowerDebtValue: _src.input.borrowerDebtValue,
            borrower: _src.input.borrower,
            debtToken: _src.input.debtToken,
            debtShareToken: _src.input.debtShareToken,
            totalDebtAssets: _src.input.totalDebtAssets,
            totalDebtShares: _src.input.totalDebtShares
        });
        dst.mocks = Mocks({
            debtTokenDecimals: _src.mocks.debtTokenDecimals,
            debtShareTokenBalanceOf: _src.mocks.debtShareTokenBalanceOf
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
