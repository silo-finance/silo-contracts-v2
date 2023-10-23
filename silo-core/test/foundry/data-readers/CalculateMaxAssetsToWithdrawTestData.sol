// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract CalculateMaxAssetsToWithdrawTestData {
    uint256 constant BP2DP_NORMALIZATION = 10 ** (18 - 4);

    struct Input {
        uint256 sumOfCollateralsValue;
        uint256 debtValue;
        uint256 ltInDp;
        uint256 borrowerCollateralAssets;
        uint256 borrowerProtectedAssets;
    }

    struct CMATWData {
        string name;
        Input input;
        uint256 maxAssets;
        bool verifyLtvAfter;
    }

    CMATWData[] allData;

    function getData() external returns (CMATWData[] memory data) {
        _add(0, 0, 0, 0, 0, 0, "when all zeros");
        _add(1, 0, 0, 1, 0, 1, "when no debt");
        _add(1, 0, 0, 0, 1, 1, "when no debt");
        _add(100, 1, 0, 0, 0, 0, "when over LT");
        _add(1e4, 1, 1 * BP2DP_NORMALIZATION, 0, 0, 0, "LT is 0.01% and LTV is 0.01%");
        _add(1e4, 1, 100 * BP2DP_NORMALIZATION, 0.5e4, 0.5e4, 9900);
        _add(1e4, 1, 100 * BP2DP_NORMALIZATION, 0.8e4, 0.2e4, 9900);
        _add(1e4, 1, 100 * BP2DP_NORMALIZATION, 1e4, 0, 9900);
        _add(1e4, 1, 100 * BP2DP_NORMALIZATION, 0, 1e4, 9900);
        _add(1e4, 1, 100 * BP2DP_NORMALIZATION, 1e4, 1e4, 2e4 - 200, "LT 1%, debt 1, so collateral must be 100 (e4)");
        _add(100, 80, 8000 * BP2DP_NORMALIZATION, 0, 0, 0, "exact LT");
        _add(101, 80, 8000 * BP2DP_NORMALIZATION, 100, 1, 1);

        // NOTICE: for super small numbers we can get invalid estimation, like here:
         _add(10, 8, 8888 * BP2DP_NORMALIZATION, 10, 10, 2, "8/(10 - 2) = 100% > LT (!)", false);

        _add(10e18, 8e18, 8888 * BP2DP_NORMALIZATION, 5e18, 5e18, 999099909990999100, "LTV after => 88,88% (1)");
        _add(10e18, 8e18, 8888 * BP2DP_NORMALIZATION, 1e18, 1e18, uint256(999099909990999100) / 5, "LTV after => 88,88% (2)");

        //  0.1e18 / (3e18 - 2882352941176470589));
         _add(3e18, 0.1e18, 8500 * BP2DP_NORMALIZATION, 2e18, 1e18, 2882352941176470589, "LTV after => 85% (!) +5wei", false);

        return allData;
    }

    function _add(
        uint256 _sumOfCollateralsValue,
        uint256 _debtValue,
        uint256 _ltInDp,
        uint256 _borrowerCollateralAssets,
        uint256 _borrowerProtectedAssets,
        uint256 _maxAssets
    ) private {
        _add(
            _sumOfCollateralsValue,
            _debtValue,
            _ltInDp,
            _borrowerCollateralAssets,
            _borrowerProtectedAssets,
            _maxAssets,
            "",
            true
        );
    }

    function _add(
        uint256 _sumOfCollateralsValue,
        uint256 _debtValue,
        uint256 _ltInDp,
        uint256 _borrowerCollateralAssets,
        uint256 _borrowerProtectedAssets,
        uint256 _maxAssets,
        string memory _name
    ) private {
        _add(
            _sumOfCollateralsValue,
            _debtValue,
            _ltInDp,
            _borrowerCollateralAssets,
            _borrowerProtectedAssets,
            _maxAssets,
            _name,
            true
        );
    }

    function _add(
        uint256 _sumOfCollateralsValue,
        uint256 _debtValue,
        uint256 _ltInDp,
        uint256 _borrowerCollateralAssets,
        uint256 _borrowerProtectedAssets,
        uint256 _maxAssets,
        string memory _name,
        bool _verifyLtvAfter
    ) private {
        uint256 i = allData.length;
        allData.push();
        allData[i].name = _name;
        allData[i].input.sumOfCollateralsValue = _sumOfCollateralsValue;
        allData[i].input.debtValue = _debtValue;
        allData[i].input.ltInDp = _ltInDp;
        allData[i].input.borrowerCollateralAssets = _borrowerCollateralAssets;
        allData[i].input.borrowerProtectedAssets = _borrowerProtectedAssets;
        allData[i].maxAssets = _maxAssets;
        allData[i].verifyLtvAfter = _verifyLtvAfter;
    }
}
