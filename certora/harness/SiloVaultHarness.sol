import {SiloVault} from "silo-vaults/contracts/SiloVault.sol";
import {IVaultIncentivesModule} from "silo-vaults/contracts/interfaces/IVaultIncentivesModule.sol";
import {IIncentivesClaimingLogic} from "silo-vaults/contracts/interfaces/IIncentivesClaimingLogic.sol";

contract SiloVaultHarness is SiloVault {
    constructor(
        address owner,
        uint256 initialTimelock,
        IVaultIncentivesModule _vaultIncentivesModule,
        address _asset,
        string memory _name,
        string memory _symbol,
        address _incentivesClaimingLogic
    ) SiloVault(owner, initialTimelock, _vaultIncentivesModule, _asset, _name, _symbol) {
        incentivesClaimingLogic = _incentivesClaimingLogic;
    }

    address immutable incentivesClaimingLogic;

    function _claimRewards() internal override {
        bytes memory data = abi.encodeWithSelector(IIncentivesClaimingLogic.claimRewardsAndDistribute.selector);
        incentivesClaimingLogic.delegatecall(data);
    }
}