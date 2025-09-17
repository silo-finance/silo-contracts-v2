# Silo V2


Incentive controllers factories:
- arbitrum: 0xe569BDc18cD807ac1cfb2C926F50D0C9B881733f, 0x8e5715Fd87606c2955a04fF9F31553e0D0BFf5e8, 0xe569BDc18cD807ac1cfb2C926F50D0C9B881733f, 0x1c5286D1b02517fBd8964cED9b38e8555F9e44dA, 0x7C355E4F3e87E3299792fa9c1791db1b70f17374, 0x2Efa5cB0B72f625465aeAc4B84AC90C8b4519C23, 0x435Ab368F5fCCcc71554f4A8ac5F5b922bC4Dc06, 0x949b90c93848231A95D018C44B0E884b92b03218, 0x41FBdd2A144e641a8396aFa1083ADc69cEf39Ee8
- avalanche: 0x2375EBa92e1b7ace8585AE7e2d23feDc10887493, 0xA013e7252EdfB2CE93eEe4073DC03eDA16AfcfEf, 0x2375EBa92e1b7ace8585AE7e2d23feDc10887493
- ink: 0xBc1FCB9B2EC31939f3702Fd8605e8986098a7eC1, 0x2265B128491c6429B2F65E1964949B4168110A1e, 0x0A9B6dd2fBebB9E3C565F3F899182F902dA89f02, 0x77cbCB96fFFe44d344c54A5868C49ad1C5AaAC6A
- mainnet: 0xc27B33c022935e88BDDe22a417c509010A7d97E4, 0xbc4eE059Cb3969DDB7770f67d9E3FDEE386f3f75, 0xc27B33c022935e88BDDe22a417c509010A7d97E4, 0xF040CAdbc2572B2aC35Ca468B93f9c9ADF0f0D69, 0x9fF91EF98baf808e06F01984BC7d2a0ec9B6a39A
- optimism: 0xc75d8E40ed4fe3CE22d190bbfEB1AAb8432fa1E8, 0x9a8C0394839F958bDA8E80dAAAd20B4680199e14, 0x3b75AF9bE511bc0582B19a330C40EC6E58EDc320, 0xbDBBf747402653A5aD6F6B8c49F2e8dCeC37fAcF
- sonic: 0x43C70cF467474821254f5232eE531a302465e923, 0xD55a06A1d30E575a37949FBb9da85C3518f21FbA, 0x22fBF354f7E8A99673559352c63Ae022E58460dd, 0x2b07e8b10293019Cb89410894E62A090a7b5bFE6, 0x0Ec2E10be6167bf99aF57716761E571bB19E701E, 0x17f2CD2CfE241aFB03950c2ce2bF6b42193d4F04, 0x0F07685A92c9B5c63a9e9Af205948BECeb8eb5f6


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
git pull
cargo build --release
cp target/release/silo-foundry-utils ../../silo-foundry-utils
cd -
./silo-foundry-utils --version
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

AGGREGATOR=1INCH FOUNDRY_PROFILE=core_with_test forge coverage --report summary --report lcov --gas-price 1 --ffi --gas-limit 40000000000 --no-match-test "_skip_|_gas_|_anvil_" > coverage/silo-core.log
 cat coverage/silo-core.log | grep -i 'silo-core/contracts/' | grep -v -E '/(test|deploy|silo-oracles)/' > coverage/silo-core.txt
 genhtml --ignore-errors inconsistent --ignore-errors range --exclude 'silo-oracles/*' --exclude '*/test/*' --exclude '*/deploy/*' -o coverage/silo-core/ lcov.info

rm lcov.info
FOUNDRY_PROFILE=oracles forge coverage --report summary --report lcov | grep -i 'silo-oracles/contracts/' > coverage/silo-oracles.log
cat coverage/silo-oracles.log | grep -i 'silo-oracles/contracts/' | grep -v -E '/(test|deploy|common|silo-core)/' > coverage/silo-oracles.txt
genhtml --ignore-errors inconsistent --ignore-errors range --exclude 'silo-core/*' --exclude 'common/*' --exclude '*/test/*' --exclude '*/deploy/*' -o coverage/silo-oracles/ lcov.info

rm lcov.info
FOUNDRY_PROFILE=vaults_with_tests forge coverage --report summary --report lcov --gas-price 1 --ffi --gas-limit 40000000000
cat coverage/silo-vaults.log | grep -i 'silo-vaults/contracts/' | grep -v -E '/(test|deploy|common|mocks|silo-core|silo-oracles)/' > coverage/silo-vaults.txt
genhtml --ignore-errors inconsistent --ignore-errors range --exclude 'silo-core/*' --exclude 'silo-oracles/*' --exclude 'common/*' --exclude '*/mocks/*' --exclude '*/test/*' --exclude '*/deploy/*' -o coverage/silo-vaults/ lcov.info
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

### New Silo deployer with Silo, ProtectedShareToken, and DebtShareToken implementations

- run `silo-core/deploy/SiloDeployerDeploy.s.sol` script
- then deploy new market
