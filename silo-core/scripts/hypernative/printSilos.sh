#!/bin/bash
CHAIN=$1

# Extract lines from the file that belong to the given chain block
# Print only those lines, grep for 0x, then extract the address (2nd field after colon) by sed

sed -n "/\"$CHAIN\"[[:space:]]*:/,/}/p" "silo-core/deploy/silo/_siloDeployments.json" | \
grep 0x | \
sed -E 's/.*: *"([^"]+)".*/\1/'
