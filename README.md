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
```

### Foundry setup for monorepo

```
git submodule add --name foundry https://github.com/foundry-rs/forge-std gitmodules/forge-std
git submodule update --init --recursive
git submodule
```

create `.remappings.txt` in main directory

```
forge-std/=gitmodules/forge-std/src/
```

this will make forge visible for imports eg: `import "forge-std/Test.sol"`.

### Remove submodule

example: 

```shell
# Remove the submodule entry from .git/config
git submodule deinit -f silo-core/lib/forge-std

# Remove the submodule directory from the superproject's .git/modules directory
rm -rf .git/modules/silo-core/lib/forge-std

# Remove the entry in .gitmodules and remove the submodule directory located at path/to/submodule
git rm -f silo-core/lib/forge-std
```

## Adding new working space

- create new workflow in `.github/workflows`
- create new directory `mkdir new-dir` with content
- create new profile in `.foundry.toml`
- add new workspace in `package.json` `workspaces` section
- run `yarn reinstall`

## Cloning external code

- In `external/` create subdirectory for cloned code eg `uniswap-v3-core/`
- clone git repo into that directory
- update `external/package.json#workspaces` with this new `uniswap-v3-core`
- update `external/uniswap-v3-core/package.json#name` to match dir name, in our example `uniswap-v3-core`

Run `yarn`, enter your new cloned workspace and you should be able to execute commands for this new workspace.

example of running scripts for workspace:

```shell
yarn workspace <workspaceName> <commandName> ...
```
