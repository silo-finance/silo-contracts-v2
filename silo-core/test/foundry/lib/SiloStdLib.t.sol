// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../../contracts/lib/SiloStdLib.sol";

contract MockSilo {
    function flashFee(ISiloConfig _config, address _token, uint256 _amount) external view returns (uint256 fee) {
        return SiloStdLib.flashFee(_config, _token, _amount);
    }
}

// forge test -vv --mc SiloStdLibTest
contract SiloStdLibTest is Test {
    ISilo.SiloData public siloData;
    ISilo.Assets public assets;

    address public config = address(10001);
    address public asset = address(10002);
    address public model = address(10003);
    MockSilo public mockSilo = new MockSilo();

    function setUp() public {}

    // function test_withdrawFees() public {}

    // function test_getFeesAndFeeReceiversWithAsset() public {}

    function test_flashFee(
        uint256 _daoFeeInBp,
        uint256 _deployerFeeInBp,
        uint256 _flashloanFee,
        address _wrongAsset,
        uint256 _amount
    ) public {
        vm.assume(_wrongAsset != asset);
        vm.assume(_flashloanFee <= 10000);
        vm.assume(_amount < type(uint256).max / 10000);

        vm.mockCall(
            config,
            abi.encodeCall(ISiloConfig.getFeesWithAsset, (address(mockSilo))),
            abi.encode(_daoFeeInBp, _deployerFeeInBp, _flashloanFee, asset)
        );

        vm.expectRevert(ISilo.Unsupported.selector);
        mockSilo.flashFee(ISiloConfig(config), _wrongAsset, _amount);

        assertEq(
            mockSilo.flashFee(ISiloConfig(config), asset, _amount), _amount * _flashloanFee / SiloStdLib._BASIS_POINTS
        );

        _amount = 1e18;
        _flashloanFee = 0.1e4;
        uint256 result = 0.1e18;

        vm.mockCall(
            config,
            abi.encodeCall(ISiloConfig.getFeesWithAsset, (address(mockSilo))),
            abi.encode(_daoFeeInBp, _deployerFeeInBp, _flashloanFee, asset)
        );

        assertEq(SiloStdLib._BASIS_POINTS, 1e4);
        assertEq(mockSilo.flashFee(ISiloConfig(config), asset, _amount), result);
    }

    function test_collateralAssetsWithInterest(
        uint256 _collateralAssets,
        uint256 _debtAssets,
        uint256 _rcomp,
        uint256 _daoFeeInBp,
        uint256 _deployerFeeInBp
    ) public {
        vm.assume(_collateralAssets < type(uint128).max);
        vm.assume(_debtAssets < type(uint128).max / 10000);
        vm.assume(_rcomp < type(uint128).max / 10000);
        vm.assume(_daoFeeInBp < 5000);
        vm.assume(_deployerFeeInBp < 5000);

        uint256 collateralAssetsWithInterest = SiloStdLib.collateralAssetsWithInterest(
            _collateralAssets, _debtAssets, _rcomp, _daoFeeInBp, _deployerFeeInBp
        );
        uint256 accruedInterest = _debtAssets * _rcomp / SiloStdLib._PRECISION_DECIMALS;
        accruedInterest -= accruedInterest * (_daoFeeInBp + _deployerFeeInBp) / SiloStdLib._BASIS_POINTS;
        uint256 result = _collateralAssets + accruedInterest;

        assertEq(collateralAssetsWithInterest, result);

        _collateralAssets = 100e18;
        _debtAssets = 40e18;
        _rcomp = 0.25e18;
        _daoFeeInBp = 0.15e4;
        _deployerFeeInBp = 0.1e4;
        result = 107.5e18;

        collateralAssetsWithInterest = SiloStdLib.collateralAssetsWithInterest(
            _collateralAssets, _debtAssets, _rcomp, _daoFeeInBp, _deployerFeeInBp
        );

        assertEq(collateralAssetsWithInterest, result);
    }

    function test_debtAssetsWithInterest(uint256 _debtAssets, uint256 _rcomp) public {
        vm.assume(_debtAssets < type(uint128).max / 10000);
        vm.assume(_rcomp < type(uint128).max / 10000);

        uint256 debtAssetsWithInterest = SiloStdLib.debtAssetsWithInterest(_debtAssets, _rcomp);
        uint256 result = _debtAssets + _debtAssets * _rcomp / SiloStdLib._PRECISION_DECIMALS;

        assertEq(debtAssetsWithInterest, result);

        _debtAssets = 60e18;
        _rcomp = 0.3e18;
        result = 78e18;

        debtAssetsWithInterest = SiloStdLib.debtAssetsWithInterest(_debtAssets, _rcomp);

        assertEq(debtAssetsWithInterest, result);
    }

    // function test_amountWithInterest(uint256 _rcomp, uint256 _amount, uint256 _daoFeeInBp, uint256 _deployerFeeInBp)
    //     public
    // {
    //     vm.assume(_rcomp < type(uint128).max / 10000);
    //     vm.assume(_amount < type(uint128).max / 10000);
    //     vm.assume(_daoFeeInBp < 5000);
    //     vm.assume(_deployerFeeInBp < 5000);

    //     vm.mockCall(
    //         model,
    //         abi.encodeCall(IInterestRateModel.getCompoundInterestRate, (address(this), asset, block.timestamp)),
    //         abi.encode(_rcomp)
    //     );

    //     vm.expectCall(
    //         model, abi.encodeCall(IInterestRateModel.getCompoundInterestRate, (address(this), asset, block.timestamp))
    //     );
    //     uint256 amountWithInterest = SiloStdLib.amountWithInterest(asset, _amount, model, 0, 0);
    //     assertEq(amountWithInterest, _amount + _amount * _rcomp / SiloStdLib._PRECISION_DECIMALS);

    //     vm.expectCall(
    //         model, abi.encodeCall(IInterestRateModel.getCompoundInterestRate, (address(this), asset, block.timestamp))
    //     );
    //     amountWithInterest = SiloStdLib.amountWithInterest(asset, _amount, model, _daoFeeInBp, _deployerFeeInBp);
    //     uint256 accruedInterest = _amount * _rcomp / SiloStdLib._PRECISION_DECIMALS;
    //     uint256 daoAndDeployerCut = accruedInterest * (_daoFeeInBp + _deployerFeeInBp) / SiloStdLib._BASIS_POINTS;
    //     assertEq(amountWithInterest, _amount + accruedInterest - daoAndDeployerCut);

    //     _rcomp = 0.5e18;
    //     _amount = 1e18;
    //     _daoFeeInBp = 0.1e4;
    //     _deployerFeeInBp = 0.1e4;
    //     uint256 result = 1.4e18;
    //     vm.mockCall(
    //         model,
    //         abi.encodeCall(IInterestRateModel.getCompoundInterestRate, (address(this), asset, block.timestamp)),
    //         abi.encode(_rcomp)
    //     );

    //     vm.expectCall(
    //         model, abi.encodeCall(IInterestRateModel.getCompoundInterestRate, (address(this), asset, block.timestamp))
    //     );
    //     amountWithInterest = SiloStdLib.amountWithInterest(asset, _amount, model, _daoFeeInBp, _deployerFeeInBp);
    //     assertEq(amountWithInterest, result);
    // }

    function test_liquidity(uint256 _collateralAssets, uint256 _debtAssets) public {
        if (_debtAssets > _collateralAssets) {
            assertEq(SiloStdLib.liquidity(_collateralAssets, _debtAssets), 0);
        } else {
            assertEq(SiloStdLib.liquidity(_collateralAssets, _debtAssets), _collateralAssets - _debtAssets);
        }
    }

    // function test_getTotalAssetsAndTotalShares(
    //     uint256 _protectedTotalSupply,
    //     uint256 _collateralTotalSupply,
    //     uint256 _debtTotalSupply,
    //     address _protectedShareToken,
    //     address _collateralShareToken,
    //     address _debtShareToken,
    //     uint256 _rcomp,
    //     uint256 _protectedAssets,
    //     uint256 _collateralAssets,
    //     uint256 _debtAssets
    // ) public {
    //     vm.assume(_rcomp < type(uint128).max);
    //     vm.assume(_protectedAssets < type(uint128).max);
    //     vm.assume(_collateralAssets < type(uint128).max);
    //     vm.assume(_debtAssets < type(uint128).max);
    //     vm.assume(_protectedShareToken != _collateralShareToken);
    //     vm.assume(_collateralShareToken != _debtShareToken);
    //     vm.assume(_protectedShareToken != _debtShareToken);

    //     vm.mockCall(
    //         _protectedShareToken, abi.encodeCall(IERC20Upgradeable.totalSupply, ()), abi.encode(_protectedTotalSupply)
    //     );
    //     vm.mockCall(
    //         _collateralShareToken,
    //         abi.encodeCall(IERC20Upgradeable.totalSupply, ()),
    //         abi.encode(_collateralTotalSupply)
    //     );
    //     vm.mockCall(_debtShareToken, abi.encodeCall(IERC20Upgradeable.totalSupply, ()), abi.encode(_debtTotalSupply));
    //     vm.mockCall(
    //         model,
    //         abi.encodeCall(IInterestRateModel.getCompoundInterestRate, (address(this), asset, block.timestamp)),
    //         abi.encode(_rcomp)
    //     );

    //     assetStorage.protectedAssets = _protectedAssets;
    //     assetStorage.collateralAssets = _collateralAssets;
    //     assetStorage.debtAssets = _debtAssets;

    //     ISiloConfig.ConfigData memory _configData = ISiloConfig.ConfigData(
    //         0.1e4,
    //         0.1e4,
    //         address(0),
    //         asset,
    //         _protectedShareToken,
    //         _collateralShareToken,
    //         _debtShareToken,
    //         address(0),
    //         address(0),
    //         model,
    //         0,
    //         0,
    //         0,
    //         0,
    //         true
    //     );

    //     uint256 totalAssets;
    //     uint256 totalShares;

    //     (totalAssets, totalShares) =
    //         SiloStdLib.getTotalAssetsAndTotalShares(_configData, ISilo.AssetType.Protected, assetStorage);

    //     assertEq(totalShares, _protectedTotalSupply);
    //     assertEq(totalAssets, _protectedAssets);

    //     (totalAssets, totalShares) =
    //         SiloStdLib.getTotalAssetsAndTotalShares(_configData, ISilo.AssetType.Collateral, assetStorage);

    //     uint256 accruedInterest = _collateralAssets * _rcomp / SiloStdLib._PRECISION_DECIMALS;
    //     uint256 daoAndDeployerFee =
    //         accruedInterest * (_configData.daoFeeInBp + _configData.deployerFeeInBp) / SiloStdLib._BASIS_POINTS;
    //     assertEq(totalShares, _collateralTotalSupply);
    //     assertEq(totalAssets, _collateralAssets + accruedInterest - daoAndDeployerFee);

    //     (totalAssets, totalShares) =
    //         SiloStdLib.getTotalAssetsAndTotalShares(_configData, ISilo.AssetType.Debt, assetStorage);

    //     accruedInterest = _debtAssets * _rcomp / SiloStdLib._PRECISION_DECIMALS;
    //     assertEq(totalShares, _debtTotalSupply);
    //     assertEq(totalAssets, _debtAssets + accruedInterest);
    // }

    // function test_getTotalAssetsAndTotalSharesFixedValues(
    //     address _protectedShareToken,
    //     address _collateralShareToken,
    //     address _debtShareToken
    // ) public {
    //     vm.assume(_protectedShareToken != _collateralShareToken);
    //     vm.assume(_collateralShareToken != _debtShareToken);
    //     vm.assume(_protectedShareToken != _debtShareToken);

    //     uint256 protectedTotalSupply = 1123e18;
    //     uint256 collateralTotalSupply = 1123e18;
    //     uint256 debtTotalSupply = 1123e18;
    //     uint256 rcomp = 0.15e18;
    //     uint256 protectedAssets = 100e18;
    //     uint256 collateralAssets = 50e18;
    //     uint256 debtAssets = 20e18;

    //     vm.mockCall(
    //         _protectedShareToken, abi.encodeCall(IERC20Upgradeable.totalSupply, ()), abi.encode(protectedTotalSupply)
    //     );
    //     vm.mockCall(
    //         _collateralShareToken,
    //         abi.encodeCall(IERC20Upgradeable.totalSupply, ()),
    //         abi.encode(collateralTotalSupply)
    //     );
    //     vm.mockCall(_debtShareToken, abi.encodeCall(IERC20Upgradeable.totalSupply, ()), abi.encode(debtTotalSupply));
    //     vm.mockCall(
    //         model,
    //         abi.encodeCall(IInterestRateModel.getCompoundInterestRate, (address(this), asset, block.timestamp)),
    //         abi.encode(rcomp)
    //     );

    //     assetStorage.protectedAssets = protectedAssets;
    //     assetStorage.collateralAssets = collateralAssets;
    //     assetStorage.debtAssets = debtAssets;

    //     ISiloConfig.ConfigData memory _configData = ISiloConfig.ConfigData(
    //         0.1e4,
    //         0.1e4,
    //         address(0),
    //         asset,
    //         _protectedShareToken,
    //         _collateralShareToken,
    //         _debtShareToken,
    //         address(0),
    //         address(0),
    //         model,
    //         0,
    //         0,
    //         0,
    //         0,
    //         true
    //     );

    //     uint256 totalAssets;
    //     uint256 totalShares;

    //     (totalAssets, totalShares) =
    //         SiloStdLib.getTotalAssetsAndTotalShares(_configData, ISilo.AssetType.Protected, assetStorage);

    //     assertEq(totalShares, protectedTotalSupply);
    //     assertEq(totalAssets, protectedAssets);

    //     (totalAssets, totalShares) =
    //         SiloStdLib.getTotalAssetsAndTotalShares(_configData, ISilo.AssetType.Collateral, assetStorage);

    //     assertEq(totalShares, collateralTotalSupply);
    //     assertEq(totalAssets, 52.4e18);

    //     (totalAssets, totalShares) =
    //         SiloStdLib.getTotalAssetsAndTotalShares(_configData, ISilo.AssetType.Debt, assetStorage);

    //     assertEq(totalShares, debtTotalSupply);
    //     assertEq(totalAssets, 23e18);
    // }

    function test_calculateUtilization(uint256 _collateralAssets, uint256 _debtAssets) public {
        uint256 dp = 1e18;

        vm.assume(_collateralAssets > 0);
        vm.assume(_debtAssets < type(uint128).max);
        uint256 u = _debtAssets * dp / _collateralAssets;
        vm.assume(u <= dp);

        assertEq(SiloStdLib.calculateUtilization(dp, _collateralAssets, _debtAssets), u);

        assertEq(SiloStdLib.calculateUtilization(dp, 1e18, 0.9e18), 0.9e18);
        assertEq(SiloStdLib.calculateUtilization(dp, 1e18, 0.1e18), 0.1e18);
        assertEq(SiloStdLib.calculateUtilization(dp, 10e18, 1e18), 0.1e18);
        assertEq(SiloStdLib.calculateUtilization(dp, 100e18, 25e18), 0.25e18);
        assertEq(SiloStdLib.calculateUtilization(dp, 100e18, 49e18), 0.49e18);
    }

    function test_calculateUtilizationWithMax(uint256 _dp, uint256 _collateralAssets, uint256 _debtAssets) public {
        vm.assume(_debtAssets < type(uint128).max);
        vm.assume(_dp < type(uint128).max);

        uint256 standardDp = 1e18;

        assertEq(SiloStdLib.calculateUtilization(standardDp, 0, _debtAssets), 0);
        assertEq(SiloStdLib.calculateUtilization(standardDp, _collateralAssets, 0), 0);
        assertEq(SiloStdLib.calculateUtilization(0, _collateralAssets, _debtAssets), 0);

        uint256 u = SiloStdLib.calculateUtilization(_dp, _collateralAssets, _debtAssets);
        assertTrue(u <= _dp);
    }
}
