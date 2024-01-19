import "./ShareTokensCommonMethods.spec";

using ShareDebtToken0 as shareDebtToken0;
using ShareCollateralToken0 as shareCollateralToken0;
using ShareProtectedCollateralToken0 as shareProtectedCollateralToken0;

methods {
    function shareProtectedCollateralToken0.totalSupply() external returns(uint256) envfree;
    function shareDebtToken0.totalSupply() external returns(uint256) envfree;
    function shareCollateralToken0.totalSupply() external returns(uint256) envfree;

    function shareProtectedCollateralToken0.balanceOf(address) external returns(uint256) envfree;
    function shareDebtToken0.balanceOf(address) external returns(uint256) envfree;
    function shareCollateralToken0.balanceOf(address) external returns(uint256) envfree;

    function shareProtectedCollateralToken0.hookReceiver() external returns(address) envfree;
    function shareDebtToken0.hookReceiver() external returns(address) envfree;
    function shareCollateralToken0.hookReceiver() external returns(address) envfree;

    function shareProtectedCollateralToken0.silo() external returns(address) envfree;
    function shareDebtToken0.silo() external returns(address) envfree;
    function shareCollateralToken0.silo() external returns(address) envfree;

    function shareProtectedCollateralToken0.name() internal returns(string memory) => simplified_name();
    function shareDebtToken0.name() internal returns(string memory) => simplified_name();
    function shareCollateralToken0.name() internal returns(string memory) => simplified_name();

    function shareProtectedCollateralToken0.symbol() internal returns(string memory) => simplified_symbol();
    function shareDebtToken0.symbol() internal returns(string memory) => simplified_symbol();
    function shareCollateralToken0.symbol() internal returns(string memory) => simplified_symbol();
}
