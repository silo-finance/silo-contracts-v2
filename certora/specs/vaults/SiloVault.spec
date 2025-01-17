using Vault0 as Vault;
using VaultIncentivesModule as VaultIncentivesModule;
// using IVaultIncentivesModule as IVaultIncentivesModule;

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

    // no implementation around, I think, currently we have an empty dummy one -- summarize somehow?
    function _.afterTokenTransfer(address,uint256,address,uint256,uint256,uint256) external => DISPATCHER(true);

    /*
    SiloVault.sol : Line 964:
    function _claimRewards() internal virtual {
        address[] memory logics = INCENTIVES_MODULE.getAllIncentivesClaimingLogics();
        bytes memory data = abi.encodeWithSelector(IIncentivesClaimingLogic.claimRewardsAndDistribute.selector);

        for (uint256 i; i < logics.length; i++) {
            logics[i].delegatecall(data);  // <-- summarizing as NONDET / assuming no side effects
            // result of call is ignored
        }
    }
     */
    function _.f57a64ae() external => NONDET; 

}

// hook Sload VaultIncentivesModule vim INCENTIVES_MODULE {
//     require vim == VaultIncentivesModule;
// }

use builtin rule sanity;
