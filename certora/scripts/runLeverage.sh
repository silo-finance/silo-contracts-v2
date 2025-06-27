#!/bin/bash

# Run leverage contract verification specs
certoraRun certora/config/leverage/LeverageDebtTokenApproval.conf --server production --msg "Leverage debt token approval"