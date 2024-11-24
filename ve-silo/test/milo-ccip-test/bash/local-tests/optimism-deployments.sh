#!/bin/bash

source ./.env

set +e

echo "Deploy ve-silo. RPC: http://127.0.0.1:8546"
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/deploy/L2Deploy.s.sol \
    --ffi --broadcast --skip-simulation --rpc-url http://127.0.0.1:8546

exit_code=$?

if [ $exit_code != 0 ]; then
  echo "ve-silo deployment failed"
  exit $exit_code
fi

echo "ve-silo deployment done."

echo "Deploy silo-core. RPC: http://127.0.0.1:8546"
FOUNDRY_PROFILE=core \
    forge script silo-core/deploy/MainnetDeploy.s.sol \
    --ffi --broadcast --skip-simulation --rpc-url http://127.0.0.1:8546

exit_code=$?

if [ $exit_code != 0 ]; then
  echo "silo-core deployment failed"
  exit $exit_code
fi

echo "silo-core deployment done."

# Chainlink oracle
echo "Deploy oracles: ChainlinkV3OracleFactory. RPC: http://127.0.0.1:8546"

FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/chainlink-v3-oracle/ChainlinkV3OracleFactoryDeploy.s.sol \
    --ffi --broadcast --skip-simulation --rpc-url http://127.0.0.1:8546

exit_code=$?

if [ $exit_code != 0 ]; then
  echo "oracles: ChainlinkV3OracleFactory deployment failed"
  exit $exit_code
fi

echo "oracles: ChainlinkV3OracleFactory deployment done."

FOUNDRY_PROFILE=core CONFIG=UniswapV3-WETH-USDC-Silo \
    forge script silo-core/deploy/silo/SiloDeployWithGaugeHookReceiver.s.sol \
    --sender 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266 \
    --ffi --broadcast --skip-simulation --rpc-url http://127.0.0.1:8546
