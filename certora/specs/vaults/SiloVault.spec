using Vault0 as Vault0;
// using Vault1 as Vault1;
using Vault2 as Vault2;
// using Vault3 as Vault3;
using VaultIncentivesModule as VaultIncentivesModule;
using SiloIncentivesControllerCL as SiloIncentivesControllerCL;
using SiloIncentivesController as SiloIncentivesController;
// using IERC4626 as IERC4626;
using Token0 as Token0;

methods {
    function _.balanceOf(address a) external => DISPATCHER(true); 

    function Vault0.convertToAssets(uint256 shares) external returns (uint256) envfree;
    function Vault2.convertToAssets(uint256 shares) external returns (uint256) envfree;

    function _.redeem(uint256 shares, address receiver, address owner) external => DISPATCHER(true); 
    function _.approve(address spender, uint256 value) external => DISPATCHER(true);
    function _.deposit(uint256, address) external => DISPATCHER(true);
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true);
    function _.asset() external => DISPATCHER(true);
    function _.withdraw(uint256,address,address) external => DISPATCHER(true);
    function _.transfer(address,uint256) external => DISPATCHER(true);
    function _.maxDeposit(address) external => DISPATCHER(true);
    function _.maxWithdraw(address) external => DISPATCHER(true);
    function _.totalSupply() external => DISPATCHER(true);

    function _.convertToAssets(uint256 shares) external => convertToAssetDispatchCVL(shares, calledContract) expect (uint256);

    function SiloVault._ERC20BalanceOf(address _token, address _account) internal returns (uint256) => CONSTANT;

    function DistributionManager._shareToken() internal returns (address) => token0();

    // no implementation around, I think, currently we have an empty dummy one -- summarize somehow?
    function _.afterTokenTransfer(address,uint256,address,uint256,uint256,uint256) external => 
        DISPATCHER(true);

    // the Math.sol implementation is very expensive (because it does things at 
    // full precision with EVM limits, among other things)
    function _.mulDiv(uint256 x, uint256 y, uint256 denominator) internal => mulDiv_cvl(x, y, denominator) expect (uint256);

    function Strings.toHexString(uint256 value, uint256 length) internal returns (string memory) => toHexString_cvl(value, length);

    function SiloVaultHarness.eip712Domain() external returns (bytes1, string, string, uint256, address, bytes32, uint256[]) => NONDET DELETE;

    function DistributionManager._getIncentivesProgramIndex(
        uint256 currentIndex,
        uint256 emissionPerSecond,
        uint256 lastUpdateTimestamp,
        uint256 distributionEnd,
        uint256 totalBalance
    ) internal returns (uint256) => _getIncentivesProgramIndexCVL(currentIndex);


    function _.claimRewards(address _to) external => NONDET;

    // this function is being used is a bad sign, since we're trying to bypass it, since the strings make things expensive
    function DistributionManager.getProgramId(string memory _programName) internal returns (bytes32) => assertFalse();

}

function assertFalse() returns bytes32 {
    assert false, "reaching some place that our spec should not allow reaching";
    return to_bytes32(0);
}


function convertToAssetDispatchCVL(uint shares, address callee) returns uint256 {
    if (callee == Vault0) {
        return Vault0.convertToAssets(shares);
    } else if (callee == Vault2) {
        return Vault2.convertToAssets(shares);
    } else {
        require false;
        return 0;
    }
}

// .. or should we do this via a hook?..
function token0() returns address {
    return Token0;
}

function _getIncentivesProgramIndexCVL(uint256 currentIndex) returns uint256 {
    uint256 res;
    require res >= currentIndex;
    return res;
}

hook Sload address wQueue withdrawQueue[INDEX uint i] {
    require i == 0 => wQueue == Vault0;
    // require wQueue[1] == Vault1;
}

hook Sload address sQueue supplyQueue[INDEX uint i] {
    require i == 0 => sQueue == Vault2;
    // require sQueue[1] == Vault3;
}

function assume2Vaults() {
    require currentContract.withdrawQueue[0] == Vault0;
    // require currentContract.withdrawQueue[1] == Vault1;
    require currentContract.supplyQueue[0] == Vault2;
    // require currentContract.supplyQueue[1] == Vault3;
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

/**
 * `toHexString` is rather expensive; e.g. leads to a loop of length 40, also 
 * plenty of shifts.
 * This summary overapproximates the behavior while keeping injectivity with 
 * respect to `value`.
 *  (in the default usage of `toHexString`, `length` adds no extra information, 
 *   but is just the number of non-0 digits of `value`.)
 */
function toHexString_cvl(uint256 value, uint256 length) returns string {
    string word;
    require keccak256(word) == keccak256(value);
    return word;
}

rule sanityVault(method f) filtered { f -> f.contract == currentContract } {
    assume2Vaults();
    env e;
    calldataarg args;
    f(e, args);
    assert true;
    satisfy true;
}

rule sanityCL(method f) filtered { f -> f.contract == SiloIncentivesControllerCL } {
    assume2Vaults();
    env e;
    bytes32 programId;
    mathint emissionsBefore = SiloIncentivesController.incentivesPrograms[programId].emissionPerSecond;
    calldataarg args;
    f(e, args);
    // assert true;
    // satisfy true;
    satisfy emissionsBefore != SiloIncentivesController.incentivesPrograms[programId].emissionPerSecond;
}
