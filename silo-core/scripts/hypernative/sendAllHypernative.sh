#!/bin/bash

FOUNDRY_PROFILE=core \
    forge script silo-core/scripts/PrintSiloAddresses.s.sol \
    --ffi --rpc-url $RPC_SONIC | \
    grep 0x

exit 1

# Sonic
FOUNDRY_PROFILE=core \
    forge script silo-core/scripts/PrintSiloAddresses.s.sol \
    --ffi --rpc-url $RPC_SONIC | \
    grep 0x | \
    ./silo-core/scripts/hypernative/sendSingleHypernativeRequest.sh sonic

EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    echo "Error occurred"
    exit $EXIT_CODE
fi
