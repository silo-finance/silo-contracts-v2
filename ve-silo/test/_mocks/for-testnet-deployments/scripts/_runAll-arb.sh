# Deploy ve-silo
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/deployments/MainnetWithMocksDeploy.s.sol \
    --ffi --broadcast --rpc-url https://arbitrum-mainnet.infura.io/v3/<_key_>

# Deploy silo-core
# Make sure a fee distributor address is set to the dev wallet
FOUNDRY_PROFILE=core \
    forge script silo-core/deploy/MainnetDeploy.s.sol \
    --ffi --broadcast --rpc-url https://arbitrum-mainnet.infura.io/v3/<_key_>

# Deploy silo-oracles. Unsiwap oracles factory
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/uniswap-v3-oracle/UniswapV3OracleFactoryDeploy.s.sol \
    --ffi --broadcast --rpc-url https://arbitrum-mainnet.infura.io/v3/<_key_>

# Deploy silo
FOUNDRY_PROFILE=core CONFIG=Silo_ETH-USDC_UniswapV3 \
    forge script silo-core/deploy/silo/SiloDeployWithGaugeHookReceiver.s.sol \
    --ffi --broadcast --rpc-url https://arbitrum-mainnet.infura.io/v3/<_key_>

# Send ETH to proposer (if balance is empty)
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/scripts/SendEthToProposer.sol \
    --ffi --broadcast --rpc-url https://arbitrum-mainnet.infura.io/v3/<_key_>

# Transfer silo token ownership to balancer token admin
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/scripts/TransferSiloMockOwnership.sol \
    --ffi --broadcast --rpc-url https://arbitrum-mainnet.infura.io/v3/<_key_>

# Approve Silo tokens and get veSilo
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/scripts/ApproveAndGetVeSilo.sol \
    --ffi --broadcast --rpc-url https://arbitrum-mainnet.infura.io/v3/<_key_>

# Run initial proposal
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/proposals/SIPV2InitWithMocks.sol \
    --ffi --broadcast --rpc-url https://arbitrum-mainnet.infura.io/v3/<_key_>

# Cast vote (Proposal Id needs to be updated)
FOUNDRY_PROFILE=ve-silo-test \
    PROPOSAL_ID=<_proposal_id_> \
    forge script ve-silo/test/_mocks/for-testnet-deployments/scripts/CastVote.sol \
    --ffi --broadcast --rpc-url https://arbitrum-mainnet.infura.io/v3/<_key_>

# Wait while time will reach a proposal deadline (1h)
# Queue proposal
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/scripts/QueueInitWithMocksProposal.sol \
    --ffi --broadcast --rpc-url https://arbitrum-mainnet.infura.io/v3/<_key_>

# Execute proposal
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/scripts/ExecuteInitWithMocksProposal.sol \
    --ffi --broadcast --rpc-url https://arbitrum-mainnet.infura.io/v3/<_key_>
