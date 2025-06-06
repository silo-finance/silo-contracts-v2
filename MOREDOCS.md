# Silo V2

Monorepo for Silo protocol. v2

## Development setup

see:

- https://yarnpkg.com/getting-started/install
- https://classic.yarnpkg.com/lang/en/docs/workspaces/

```shell
# from root dir
git clone <repo>
git hf init

nvm install 18
nvm use 18

# this is for ode 18, for other versions please check https://yarnpkg.com/getting-started/install
corepack enable
corepack prepare yarn@stable --activate

npm i -g yarn
yarn install

git config core.hooksPath .githooks/
```

### Foundry setup for monorepo

```
git submodule add --name foundry https://github.com/foundry-rs/forge-std gitmodules/forge-std
git submodule add --name silo-foundry-utils https://github.com/silo-finance/silo-foundry-utils gitmodules/silo-foundry-utils
forge install OpenZeppelin/openzeppelin-contracts --no-commit 
forge install OpenZeppelin/openzeppelin-contracts-upgradeable --no-commit
git submodule add --name gitmodules/uniswap/v3-periphery https://github.com/Uniswap/v3-periphery gitmodules/uniswap/v3-periphery 
git submodule add --name gitmodules/chainlink https://github.com/smartcontractkit/chainlink gitmodules/chainlink 
git submodule add --name lz_gauges https://github.com/LayerZero-Labs/lz_gauges gitmodules/lz_gauges
git submodule add --name layer-zero-examples https://github.com/LayerZero-Labs/solidity-examples gitmodules/layer-zero-examples
git submodule add --name chainlink-ccip https://github.com/smartcontractkit/ccip gitmodules/chainlink-ccip
git submodule add --name openzeppelin5 https://github.com/OpenZeppelin/openzeppelin-contracts@5.0.2 gitmodules/openzeppelin-contracts-5
git submodule add --name openzeppelin-contracts-upgradeable-5 https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable gitmodules/openzeppelin-contracts-upgradeable-5
git submodule add --name morpho-blue https://github.com/morpho-org/morpho-blue/ gitmodules/morpho-blue

git submodule update --init --recursive
git submodule
```

create `.remappings.txt` in main directory

```
forge-std/=gitmodules/forge-std/src/
```

this will make forge visible for imports eg: `import "forge-std/Test.sol"`.

### Build Silo Foundry Utils
```bash
cd gitmodules/silo-foundry-utils
cargo build --release
cp target/release/silo-foundry-utils ../../silo-foundry-utils
```

More about silo foundry utils [here](https://github.com/silo-finance/silo-foundry-utils).

### Remove submodule

example:

```shell
# Remove the submodule entry from .git/config
git submodule deinit -f gitmodules/silo-foundry-utils

# Remove the submodule directory from the super project's .git/modules directory
rm -rf .git/modules/gitmodules/silo-foundry-utils

# Remove the entry in .gitmodules and remove the submodule directory located at path/to/submodule
rm -rf .git/modules/gitmodules/silo-foundry-utils
```

### Update submodule
```shell
git submodule update --remote gitmodules/<submodule>
```

If you want to update to specific commit:
1. cd `gitmodules/<module>`
2. `git checkout <commit>`
3. commit changes (optionally update `branch` section in `.gitmodules`, however this make no difference)

## Adding new working space

- create new workflow in `.github/workflows`
- create new directory `mkdir new-dir` with content
- create new profile in `.foundry.toml`
- add new workspace in `package.json` `workspaces` section
- run `yarn reinstall`

## Cloning external code

- In `external/` create subdirectory for cloned code eg `uniswap-v3-core/`
- clone git repo into that directory

**NOTICE**: do not run `yarn install` directly from workspace directory. It will create separate `yarn.lock` and it will
act like separate repo, not part of monorepo. It will cause issues when trying to access other workspaces eg as
dependency.
- you need to remove `./git` directories in order to commit cloned code
- update `external/package.json#workspaces` with this new `uniswap-v3-core`
- update `external/uniswap-v3-core/package.json#name` to match dir name, in our example `uniswap-v3-core`

Run `yarn install`, enter your new cloned workspace, and you should be able to execute commands for this new workspace.

example of running scripts for workspace:

```shell
yarn workspace <workspaceName> <commandName> ...
```

## Coverage Report


```shell
brew install lcov

rm lcov.info
mkdir coverage

FOUNDRY_PROFILE=core_with_test forge coverage --report summary --report lcov --gas-price 1 --ffi --gas-limit 40000000000 --no-match-test "_skip_|_gas_|_anvil_" > coverage/silo-core.log
cat coverage/silo-core.log | grep -i 'silo-core/contracts/' > coverage/silo-core.txt
genhtml --ignore-errors inconsistent -ignore-errors range -o coverage/silo-core/ lcov.info

rm lcov.info
FOUNDRY_PROFILE=oracles forge coverage --report summary --report lcov | grep -i 'silo-oracles/contracts/' > coverage/silo-oracles.log
cat coverage/silo-oracles-report.log | grep -i 'silo-oracles/contracts/' > coverage/silo-oracles.txt
genhtml -o coverage/silo-oracles/ lcov.info

rm lcov.info
FOUNDRY_PROFILE=vaults_with_tests forge coverage --report summary --report lcov --gas-price 1 --ffi --gas-limit 40000000000
cat coverage/silo-vaults.log | grep -i 'silo-vaults/contracts/' > coverage/silo-vaults.txt
genhtml --ignore-errors inconsistent -ignore-errors range -o  coverage/silo-vaults/ lcov.info
```

## Rounding policy

Check `Rounding.sol` for rounding policy.

## Setup Echidna

- https://github.com/crytic/echidna
- https://github.com/crytic/properties

```shell
brew install echidna
git submodule add --name crytic-properties https://github.com/crytic/properties gitmodules/crytic/properties


# before you can run any echidna tests, run the script:
./silo-core/scripts/echidnaBefore.sh
# after you done run this to revert changes:
./silo-core/scripts/echidnaAfter.sh
```

## Gas

```shell
# generate snapshot file
FOUNDRY_PROFILE=core_test forge snapshot --desc --no-match-test "_skip_" --no-match-contract "SiloIntegrationTest" --ffi
# check gas difference
FOUNDRY_PROFILE=core_test forge snapshot --desc --check --no-match-test "_skip_" --no-match-contract "SiloIntegrationTest" --ffi
# better view, with % change
FOUNDRY_PROFILE=core_test forge snapshot --diff --desc --no-match-test "_skip_" --no-match-contract "SiloIntegrationTest" --ffi
```

## Deployment

set env variable `PRIVATE_KEY` then run

```bash
FOUNDRY_PROFILE=core \
forge script silo-core/deploy/MainnetDeploy.s.sol \
--ffi --broadcast --rpc-url https://arbitrum-mainnet.infura.io/v3/<key>
```

In case you deploying without ve-silo, go to `SiloFactoryDeploy` and `SiloDeployWithGaugeHookReceiver` and set
`daoFeeReceiver` and `timelock` addresses manually to eg. deployer address.

### New market deploy

- run `silo-core/deploy/silo/SiloDeployWithGaugeHookReceiver.s.sol` script

### New Silo deployer with Silo, ProtectedShareToken, and DebtShareToken implementations

- run `silo-core/deploy/SiloDeployerDeploy.s.sol` script
- then deploy new market


## Known issues:
- Silo incentives controller with version < 3.6.0 has issue with `getProgramName` fn. It fails to convert the immediate distribution program name into a proper string representation.
Silos incentives controller with this issue: Sonic 1 - 101, Arbitrum 100 - 111, Optimism - 100, Ink - 100 - 101.

## Deployed silo lending markets versions
**Network: Sonic**
 id 1 - 12 version [0.18.0](https://github.com/silo-finance/silo-contracts-v2/releases/tag/0.18.0) \
 SiloDeployer [0x44e9c695624dad0bb3690a40c90e6d7964b32d3d](https://sonicscan.org/address/0x44e9c695624dad0bb3690a40c90e6d7964b32d3d) \
 Silo Implementation [0x85b0273b0B415F9e28B9ce820240F4aa097F2a29](https://sonicscan.org/address/0x85b0273b0B415F9e28B9ce820240F4aa097F2a29) \
 Silo Factory [0xa42001D6d2237d2c74108FE360403C4b796B7170](https://sonicscan.org/address/0xa42001D6d2237d2c74108FE360403C4b796B7170)

 id 13 - 99 version [1.1.0](https://github.com/silo-finance/silo-contracts-v2/releases/tag/1.1.0) \
 SiloDeployer [0x7C7B42dE0CE7A77d66d1C4744002083Ea0aE8a8d](https://sonicscan.org/address/0x7C7B42dE0CE7A77d66d1C4744002083Ea0aE8a8d) \
 Silo Implementation [0xCfBEbcf6Bc36F631cBb1011633fFC014dB3dB22d](https://sonicscan.org/address/0xCfBEbcf6Bc36F631cBb1011633fFC014dB3dB22d) \
 Silo Factory [0xa42001D6d2237d2c74108FE360403C4b796B7170](https://sonicscan.org/address/0xa42001D6d2237d2c74108FE360403C4b796B7170)

 id 100 version [3.4.0](https://github.com/silo-finance/silo-contracts-v2/releases/tag/3.4.0) \
 SiloDeployer [0xd3e800f6cfE31253911C3b941594286fCD007116](https://sonicscan.org/address/0xd3e800f6cfE31253911C3b941594286fCD007116) \
 Silo Implementation [0xc2B2e6e30F0F059cC05bF5B29d452A770944f0E3](https://sonicscan.org/address/0xc2B2e6e30F0F059cC05bF5B29d452A770944f0E3) \
 Silo Factory [0x4e9dE3a64c911A37f7EB2fCb06D1e68c3cBe9203](https://sonicscan.org/address/0x4e9dE3a64c911A37f7EB2fCb06D1e68c3cBe9203)

 id 101 - version [3.5.0](https://github.com/silo-finance/silo-contracts-v2/releases/tag/3.5.0) \
 SiloDeployer [0x2Efa5cB0B72f625465aeAc4B84AC90C8b4519C23](https://sonicscan.org/address/0x2Efa5cB0B72f625465aeAc4B84AC90C8b4519C23) \
 Silo Implementation [0x435Ab368F5fCCcc71554f4A8ac5F5b922bC4Dc06](https://sonicscan.org/address/0x435Ab368F5fCCcc71554f4A8ac5F5b922bC4Dc06) \
 Silo Factory [0x4e9dE3a64c911A37f7EB2fCb06D1e68c3cBe9203](https://sonicscan.org/address/0x4e9dE3a64c911A37f7EB2fCb06D1e68c3cBe9203)
 
 **Network: Arbitrum** \
 id 100 - 108 version [3.4.0](https://github.com/silo-finance/silo-contracts-v2/releases/tag/3.4.0) \
 SiloDeployer [0x1d244E66e9A875F325ca85Db3077d3C446090Ec5](https://arbiscan.io/address/0x1d244E66e9A875F325ca85Db3077d3C446090Ec5) \
 Silo Implementation [0xc216dFac5e29EafC4ed826A3bB79dB72E1aC2535](https://arbiscan.io/address/0xc216dFac5e29EafC4ed826A3bB79dB72E1aC2535) \
 Silo Factory [0x384DC7759d35313F0b567D42bf2f611B285B657C](https://arbiscan.io/address/0x384DC7759d35313F0b567D42bf2f611B285B657C)

  id 109 - version [3.5.0](https://github.com/silo-finance/silo-contracts-v2/releases/tag/3.5.0) \
 SiloDeployer [0xc95Cce9e3A23d8c1c51a61CeAa5ee5927BA9F521](https://arbiscan.io/address/0xc95Cce9e3A23d8c1c51a61CeAa5ee5927BA9F521) \
 Silo Implementation [0x9b550BF0351986342959d4447c5851e570766238](https://arbiscan.io/address/0x9b550BF0351986342959d4447c5851e570766238) \
 Silo Factory [0x384DC7759d35313F0b567D42bf2f611B285B657C](https://arbiscan.io/address/0x384DC7759d35313F0b567D42bf2f611B285B657C)

 **Network: Optimism** \
 id 100 version [3.4.0](https://github.com/silo-finance/silo-contracts-v2/releases/tag/3.4.0) \
 SiloDeployer [0x12D73b8dC92961C71782154B70416c4A1fb7dD12](https://optimistic.etherscan.io/address/0x12D73b8dC92961C71782154B70416c4A1fb7dD12) \
 Silo Implementation [0xBc0131AA1FF58F628ceAcE15751F703E17E24C69](https://optimistic.etherscan.io/address/0xBc0131AA1FF58F628ceAcE15751F703E17E24C69) \
 Silo Factory [0xFa773e2c7df79B43dc4BCdAe398c5DCA94236BC5](https://optimistic.etherscan.io/address/0xFa773e2c7df79B43dc4BCdAe398c5DCA94236BC5)

 id 101 -  version [3.5.0](https://github.com/silo-finance/silo-contracts-v2/releases/tag/3.5.0) \
 SiloDeployer [0x6225eF6256f945f490204D7F71e80B0FF84523dD](https://optimistic.etherscan.io/address/0x6225eF6256f945f490204D7F71e80B0FF84523dD) \
 Silo Implementation [0x7ef3055d2B76214Df9Ae74D42944e2917D08Bd78](https://optimistic.etherscan.io/address/0x7ef3055d2B76214Df9Ae74D42944e2917D08Bd78) \
 Silo Factory [0xFa773e2c7df79B43dc4BCdAe398c5DCA94236BC5](https://optimistic.etherscan.io/address/0xFa773e2c7df79B43dc4BCdAe398c5DCA94236BC5)

 **Network: Ink** \
 id 100 - 101 version [3.4.0](https://github.com/silo-finance/silo-contracts-v2/releases/tag/3.4.0) \
 SiloDeployer [0x2a4507b28c6E620A2Dcc05062F250D3d1C0f3faa](https://explorer.inkonchain.com/address/0x2a4507b28c6E620A2Dcc05062F250D3d1C0f3faa) \
 Silo Implementation [0x4576fa3e2E061376431619B5631C25c99fFa27bd](https://explorer.inkonchain.com/address/0x4576fa3e2E061376431619B5631C25c99fFa27bd) \
 Silo Factory [0xD13921239e3832FDC4141FDE544D3D058B529A5D](https://explorer.inkonchain.com/address/0xD13921239e3832FDC4141FDE544D3D058B529A5D)

 id 102 -  version [3.5.0](https://github.com/silo-finance/silo-contracts-v2/releases/tag/3.4.0) \
 SiloDeployer [0xb59605f42A1c564aacc9387132Ad712295b21E55](https://explorer.inkonchain.com/address/0xb59605f42A1c564aacc9387132Ad712295b21E55) \
 Silo Implementation [0xd3De080436b9d38DC315944c16d89C050C414Fed](https://explorer.inkonchain.com/address/0xd3De080436b9d38DC315944c16d89C050C414Fed) \
 Silo Factory [0xD13921239e3832FDC4141FDE544D3D058B529A5D](https://explorer.inkonchain.com/address/0xD13921239e3832FDC4141FDE544D3D058B529A5D)
