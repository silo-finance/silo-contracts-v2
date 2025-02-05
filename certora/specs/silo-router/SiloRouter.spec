using SiloRouterHarness as SiloRouterHarness;

use builtin rule sanity filtered { f -> 
    f.contract == SiloRouterHarness && f.selector != sig:multicall(bytes[]).selector
}
