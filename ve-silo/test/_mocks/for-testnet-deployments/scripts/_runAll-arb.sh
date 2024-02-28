# Deploy ve-silo
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/deployments/MainnetWithMocksDeploy.s.sol \
    --ffi --broadcast --rpc-url https://arbitrum-mainnet.infura.io/v3/<_key_>

# Deploy silo-core
FOUNDRY_PROFILE=core \
    forge script silo-core/deploy/MainnetDeploy.s.sol \
    --ffi --broadcast --rpc-url https://arbitrum-mainnet.infura.io/v3/<_key_>

# Deploy silo
FOUNDRY_PROFILE=core CONFIG=ETH-USDC_UniswapV3_Silo \
    forge script silo-core/deploy/silo/SiloDeploy.s.sol \
    --ffi --broadcast --rpc-url https://arbitrum-mainnet.infura.io/v3/<_key_>

# Send ETH to proposer
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/scripts/SendEthToProposer.sol \
    --ffi --broadcast --rpc-url https://arbitrum-mainnet.infura.io/v3/<_key_>

# Transfer silo token ownership to balancer token admin
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/scripts/TransferSiloMockOwnership.sol \
    --ffi --broadcast --rpc-url https://arbitrum-mainnet.infura.io/v3/<_key_>

# Approve BPT and get veSilo
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
