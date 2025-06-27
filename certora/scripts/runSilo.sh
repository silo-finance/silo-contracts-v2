#!/bin/bash

# Run various Silo verification specs
certoraRun certora/config/silo/risk_assessment.conf --server production --msg "Risk assessment"
certoraRun certora/config/silo/risk_assessment_silo.conf --server production --msg "Risk assessment silo"
certoraRun certora/config/silo/access-single-silo.conf --server production --msg "Access single silo"
certoraRun certora/config/silo/accrue_hooks.conf --server production --msg "Accrue hooks"
certoraRun certora/config/silo/accrue_noAdditionalEffect.conf --server production --msg "Accrue no additional effect"
certoraRun certora/config/silo/customerSuggested.conf --server production --msg "Customer suggested"
certoraRun certora/config/silo/mathLib.conf --server production --msg "Math lib"
certoraRun certora/config/silo/maxCorectness.conf --server production --msg "Max correctness"
certoraRun certora/config/silo/methods_integrity.conf --server production --msg "Methods integrity"
certoraRun certora/config/silo/noDebtInBoth.conf --server production --msg "No debt in both"
certoraRun certora/config/silo/preview_integrity.conf --server production --msg "Preview integrity"
certoraRun certora/config/silo/silo_config.conf --server production --msg "Silo config"
certoraRun certora/config/silo/solvent_user.conf --server production --msg "Solvent user"
certoraRun certora/config/silo/third_party_protections.conf --server production --msg "Third party protections"
certoraRun certora/config/silo/whoCanCallSetSilo.conf --server production --msg "Who can call set silo"
