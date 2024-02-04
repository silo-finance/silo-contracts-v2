using SiloConfigWithStorage as siloConfig;

methods {
    // Getters:
    // returns (address asset)
    function siloConfig.getAssetForSilo(address) external returns(address) envfree;
    // returns (address silo0, address silo1)
    function siloConfig.getSilos() external returns(address, address) envfree;
    // returns (address protectedShareToken, address collateralShareToken, address debtShareToken)
    function siloConfig.getShareTokens(address) external returns(address, address, address) envfree;
    // returns (uint256 daoFee, uint256 deployerFee, uint256 flashloanFee, address asset)
    function siloConfig.getFeesWithAsset(address) external returns(uint256, uint256, uint256, address) envfree;
    function siloConfig.getConfig(address) external returns(ISiloConfig.ConfigData) envfree;
}
