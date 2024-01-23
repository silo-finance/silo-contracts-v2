using SiloConfig as siloConfig;

methods {
    // Getters:
    function siloConfig.getAssetForSilo(address) external returns(address) envfree;
    function siloConfig.getSilos() external returns(address, address) envfree;
    function siloConfig.getShareTokens(address) external returns(address, address, address) envfree;
}
