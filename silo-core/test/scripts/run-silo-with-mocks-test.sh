#!/bin/bash

source ./.env
FOUNDRY_PROFILE=core-test forge test --mc SiloMainnetWithMocksIntegrationTest --ffi -vvv --rpc-url $SILO_DEPLOYMENT_NODE
