import {SiloVault} from "silo-vaults/contracts/SiloVault.sol";
import {IVaultIncentivesModule} from "silo-vaults/contracts/interfaces/IVaultIncentivesModule.sol";

contract SiloVaultHarness is SiloVault {
    constructor(
        address owner,
        uint256 initialTimelock,
        IVaultIncentivesModule _vaultIncentivesModule,
        address _asset,
        string memory _name,
        string memory _symbol
    ) SiloVault(owner, initialTimelock, _vaultIncentivesModule, _asset, _name, _symbol) {}
}