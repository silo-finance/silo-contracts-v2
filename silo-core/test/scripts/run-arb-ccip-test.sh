#!/bin/bash

source ./.env

FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/scripts/SendEthToProposer.sol \
    --ffi --broadcast --rpc-url $SILO_DEPLOYMENT_NODE

FOUNDRY_PROFILE=core-test forge test --mt test_anvil_veSiloAndMiloTokenArbitrum --ffi -vvv --rpc-url $SILO_DEPLOYMENT_NODE
