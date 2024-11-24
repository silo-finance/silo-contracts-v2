#!/bin/bash

source ./.env

set +e

echo "Deploy ve-silo. RPC: http://127.0.0.1:8545"
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/deploy/MainnetDeploy.s.sol \
    --ffi --broadcast --skip-simulation --rpc-url http://127.0.0.1:8545

exit_code=$?

if [ $exit_code != 0 ]; then
  echo "ve-silo deployment failed"
  exit $exit_code
fi

echo "ve-silo deployment done."

echo "Deploy silo-core. RPC: http://127.0.0.1:8545"
FOUNDRY_PROFILE=core \
    forge script silo-core/deploy/MainnetDeploy.s.sol \
    --ffi --broadcast --skip-simulation --rpc-url http://127.0.0.1:8545

exit_code=$?

if [ $exit_code != 0 ]; then
  echo "silo-core deployment failed"
  exit $exit_code
fi

echo "silo-core deployment done."
