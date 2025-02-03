using SiloRouterHarness as SiloRouterHarness;

use builtin rule sanity filtered { f -> 
    f.contract == SiloRouterHarness // && f.selector != multicall(bytes[]).selector
}
