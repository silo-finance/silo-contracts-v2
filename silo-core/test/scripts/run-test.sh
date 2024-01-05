#!/bin/bash

source ./.env
FOUNDRY_PROFILE=core-test forge test --mc SiloIntegrationTest --ffi -vvv --rpc-url $SILO_DEPLOYMENT_NODE
