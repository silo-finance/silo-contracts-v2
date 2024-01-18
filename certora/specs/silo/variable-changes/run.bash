#!/bin/bash

# to verify the particular function
# --method "deposit(uint256,address)"

# Run certora
certoraRun certora/config/silo/silo0.conf \
    --parametric_contracts Silo0 \
    --msg "Viriables change Silo0" \
    --verify "Silo0:certora/specs/silo/variable-changes/VariableChangesSilo0.spec"
