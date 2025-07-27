
import { SiloRouterV2 } from "silo-core/contracts/silo-router/SiloRouterV2.sol";

contract SiloRouterHarness is SiloRouterV2 {
    constructor (address _initialOwner, address _implementation) SiloRouterV2(_initialOwner, _implementation) {
        // __Ownable_init(_initialOwner);

        IMPLEMENTATION = _implementation;
    }
}
