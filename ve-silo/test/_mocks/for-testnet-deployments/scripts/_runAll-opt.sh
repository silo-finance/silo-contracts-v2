# Deploy ve-silo
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/deployments/L2WithMocksDeploy.s.sol \
    --ffi --broadcast --rpc-url https://optimism-mainnet.infura.io/v3/<_key_>

# Deploy silo-oracles. Unsiwap oracles factory
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/uniswap-v3-oracle/UniswapV3OracleFactoryDeploy.s.sol \
    --ffi --broadcast --rpc-url https://optimism-mainnet.infura.io/v3/<_key_>

# Deploy silo-core
# Make sure addresses updated (fee disctributor and timelock)
FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/MainnetDeploy.s.sol \
        --ffi --broadcast --rpc-url https://optimism-mainnet.infura.io/v3/<_key_>

# Deploy silo
FOUNDRY_PROFILE=core CONFIG=UniswapV3-WETH-USDC-Silo \
    forge script silo-core/deploy/silo/SiloDeploy.s.sol \
    --ffi --broadcast --rpc-url https://optimism-mainnet.infura.io/v3/<_key_>
