#!/bin/bash

source ./.env
anvil --fork-url $RPC_OPTIMISM --fork-block-number 127681110 --port 8546
