#!/bin/bash

source ./.env
anvil --fork-url $RPC_MAINNET --fork-block-number 20977800 --port 8586
