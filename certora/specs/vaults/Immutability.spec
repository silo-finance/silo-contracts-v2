// SPDX-License-Identifier: GPL-2.0-or-later
using SiloVaultActionsLib as siloVaultActionsLib;

methods {
    function multicall(bytes[]) external returns(bytes[]) => NONDET DELETE;
}

persistent ghost bool delegateCall;

hook DELEGATECALL(uint g, address addr, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    if (addr != siloVaultActionsLib)    // the libraries are OK
    {
        delegateCall = true;
    }
}

// Check that the contract is truly immutable.
rule noDelegateCalls(method f, env e, calldataarg data)
    filtered {
        f -> (f.contract == currentContract)
    }
{
    // Set up the initial state.
    require !delegateCall;
    f(e,data);
    assert !delegateCall;
}
