#!/bin/bash

source ./.env
anvil --fork-url $RPC_ARBITRUM --fork-block-number 271581360 --port 8545
