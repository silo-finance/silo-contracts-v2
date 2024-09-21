// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ISiloMock {
    /// @notice Retrieves the total amounts of collateral and debt assets
    /// @return totalCollateralAssets The total amount of assets of type 'Collateral'
    /// @return totalDebtAssets The total amount of debt assets of type 'Debt'
    function getCollateralAndDebtAssets()
        external
        view
        returns (uint256 totalCollateralAssets, uint256 totalDebtAssets);

    /// @notice Retrieves the total amounts of collateral and protected (non-borrowable) assets
    /// @return totalCollateralAssets The total amount of assets of type 'Collateral'
    /// @return totalProtectedAssets The total amount of protected (non-borrowable) assets
    function getCollateralAndProtectedAssets()
        external
        view
        returns (uint256 totalCollateralAssets, uint256 totalProtectedAssets);
    
    /// @notice Retrieves the raw total amount of assets based on provided type (direct storage access)
    function getTotalAssetsStorage(uint256 _assetType) external view returns (uint256);

    /// @dev There are 3 types of accounting in the system: for non-borrowable collateral deposit called "protected",
    ///      for borrowable collateral deposit called "collateral" and for borrowed tokens called "debt". System does
    ///      identical calculations for each type of accounting but it uses different data. To avoid code duplication
    ///      this enum is used to decide which data should be read.
    enum AssetType {
        Protected, // default
        Collateral,
        Debt
    }

    struct Assets {
        uint256 assets;
    }
}

abstract contract SiloMock is ISiloMock {
    mapping(AssetType => Assets) public override total;
    uint256 private interestRateTimestamp;

    function getCollateralAndProtectedAssets()
        external
        view
        returns (uint256 totalCollateralAssets, uint256 totalProtectedAssets)
    {
        totalCollateralAssets = total[AssetType.Collateral].assets;
        totalProtectedAssets = total[AssetType.Protected].assets;
    }

    function getCollateralAndDebtAssets()
        external
        view
        returns (uint256 totalCollateralAssets, uint256 totalDebtAssets)
    {
        totalCollateralAssets = total[AssetType.Collateral].assets;
        totalDebtAssets = total[AssetType.Debt].assets;
    }

    function getSiloDataInterestRateTimestamp() external view returns (uint256) {
        return interestRateTimestamp;
    }
}
