
import { SiloRouter } from "silo-core/contracts/silo-router/SiloRouter.sol";

contract SiloRouterHarness is SiloRouter {
    constructor (address _initialOwner, address _implementation) SiloRouter(_initialOwner, _implementation) {
        __Ownable_init(_initialOwner);

        IMPLEMENTATION = _implementation;
    }
}
