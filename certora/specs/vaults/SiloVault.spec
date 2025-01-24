using Vault0 as Vault0;
// using Vault1 as Vault1;
using Vault2 as Vault2;
// using Vault3 as Vault3;
using VaultIncentivesModule as VaultIncentivesModule;
using SiloIncentivesControllerCL as SiloIncentivesControllerCL;
// using IERC4626 as IERC4626;

methods {
    function _.balanceOf(address a) external => DISPATCHER(true); 
    function _.convertToAssets(uint256) external => DISPATCHER(true);
    function _.redeem(uint256 shares, address receiver, address owner) external => DISPATCHER(true); 
    function _.approve(address spender, uint256 value) external => DISPATCHER(true);
    function _.deposit(uint256, address) external => DISPATCHER(true);
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true);
    function _.asset() external => DISPATCHER(true);
    function _.withdraw(uint256,address,address) external => DISPATCHER(true);
    function _.transfer(address,uint256) external => DISPATCHER(true);
    function _.maxDeposit(address) external => DISPATCHER(true);
    function _.maxWithdraw(address) external => DISPATCHER(true);

    function _.claimRewardsAndDistribute() external => claimRewardsAndDistribute_cvl() expect void;

    // no implementation around, I think, currently we have an empty dummy one -- summarize somehow?
    function _.afterTokenTransfer(address,uint256,address,uint256,uint256,uint256) external => DISPATCHER(true);

    // biggy for summarizing -- the Math.sol implementation is very expensive (because it does things at full precision, among other things)
    function _.mulDiv(uint256 x, uint256 y, uint256 denominator) internal => mulDiv_cvl(x, y, denominator) expect (uint256);

    // function Strings.toHexString(uint256 value, uint256 length) internal returns (string memory) => CONSTANT;
}

hook Sload address wQueue withdrawQueue[INDEX uint i] {
    require i == 0 => wQueue == Vault0;
    // require wQueue[1] == Vault1;
}

hook Sload address sQueue supplyQueue[INDEX uint i] {
    require i == 0 => sQueue == Vault2;
    // require sQueue[1] == Vault3;
}

// function assume2Vaults() {
//    require currentContract.withdrawQueue[0] == Vault0;
//    // require currentContract.withdrawQueue[1] == Vault1;
//    require currentContract.supplyQueue[0] == Vault2;
//    // require currentContract.supplyQueue[1] == Vault3;
// }

function claimRewardsAndDistribute_cvl() {
    env e;
    SiloIncentivesControllerCL.claimRewardsAndDistribute(e);
}

/*
 * model gitmodules/openzeppelin-contracts-5/contracts/utils/math/Math.sol
 * full precision (using mathints)
 * "optimistic" wrt overflow and div by 0 (use in @withoutrevert contexts is safe)
 */
function mulDiv_cvl(uint256 x, uint256 y, uint256 denominator) returns uint256 {
    require denominator != 0;
    return require_uint256((x * y) / denominator);
}

// ghost toHex(uint256, uint256) returns uint;
// 
// function toHexString_cvl(uint256 value, uint256 length) returns string {
//     return "0x".push(toHex(value, length))); // "bla"; // TODO -- either implement, or summarize (e.g. as injective)
// }

// use builtin rule sanity filtered { f -> f.contract == currentContract };

rule sanity(method f) filtered { f -> f.contract == currentContract } {
//     assume2Vaults();
    env e;
    calldataarg args;
    f(e, args);
    assert true;
    satisfy true;
}
