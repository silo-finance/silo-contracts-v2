#!/bin/bash

source ./.env

set +e

echo "Deploy ve-silo. RPC: $SILO_DEPLOYMENT_NODE"
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/test/_mocks/for-testnet-deployments/deployments/MainnetWithMocksDeploy.s.sol \
    --ffi --broadcast --rpc-url $SILO_DEPLOYMENT_NODE

exit_code=$?

if [ $exit_code != 0 ]; then
  echo "ve-silo deployment failed"
  exit $exit_code
fi

echo "ve-silo deployment done."

echo "Deploy silo-core. RPC: $SILO_DEPLOYMENT_NODE"
FOUNDRY_PROFILE=core \
    forge script silo-core/deploy/MainnetDeploy.s.sol \
    --ffi --broadcast --rpc-url $SILO_DEPLOYMENT_NODE

exit_code=$?

if [ $exit_code != 0 ]; then
  echo "silo-core deployment failed"
  exit $exit_code
fi

echo "silo-core deployment done."

# Uniswap oracle
echo "Deploy oracles: UniswapV3OracleFactory. RPC: $SILO_DEPLOYMENT_NODE"
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/uniswap-v3-oracle/UniswapV3OracleFactoryDeploy.s.sol \
    --ffi --broadcast --rpc-url $SILO_DEPLOYMENT_NODE

exit_code=$?

if [ $exit_code != 0 ]; then
  echo "oracles: UniswapV3OracleFactory deployment failed"
  exit $exit_code
fi

echo "oracles: UniswapV3OracleFactory deployment done."

# FOUNDRY_PROFILE=oracles CONFIG=UniV3-ETH-USDC-0.3 \
#     forge script silo-oracles/deploy/uniswap-v3-oracle/UniswapV3OracleDeploy.s.sol \
#     --ffi --broadcast --rpc-url $SILO_DEPLOYMENT_NODE


FOUNDRY_PROFILE=core CONFIG=FULL_CONFIG_TEST \
    forge script silo-core/deploy/silo/SiloDeploy.s.sol \
    --sender 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266 \
    --ffi --broadcast --rpc-url $SILO_DEPLOYMENT_NODE

