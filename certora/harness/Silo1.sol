// SPDX-License-Identifier: BUSL-1.1
import {Silo, ISiloFactory} from "../../silo-core/contracts/Silo.sol";
contract Silo1 is Silo {
    constructor(ISiloFactory _siloFactory) Silo(_siloFactory)  {}

}