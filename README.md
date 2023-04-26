# Silo V2

Monorepo for Silo protocol. v2

## Development setup

see: https://classic.yarnpkg.com/lang/en/docs/workspaces/

```shell
# from root dir
git clone <repo>
git hf init

nvm install 18
nvm use 18
npm i -g yarn

# for modern version of yarn
yarn set version berry

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
