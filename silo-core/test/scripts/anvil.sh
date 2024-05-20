#!/bin/bash

source ./.env
anvil --fork-url $RPC_MAINNET --fork-block-number 18434580 --port 8586
