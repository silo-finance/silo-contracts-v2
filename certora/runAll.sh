#!/usr/bin/env bash
certoraRun certora/config/silo/risk_assessment.conf --server staging
certoraRun certora/config/silo/risk_assessment_silo.conf --server staging --rule check_sanity --msg "silo check_sanity"  
certoraRun certora/config/silo/risk_assessment_silo.conf --server staging --rule RA_reentrancyGuardStatusChanged --msg "silo RA_reentrancyGuardStatusChanged"  
certoraRun certora/config/silo/risk_assessment_silo.conf --server staging --rule RA_whoMustLoadCrossNonReentrant --msg "silo RA_whoMustLoadCrossNonReentrant"  
certoraRun certora/config/silo/risk_assessment_silo.conf --server staging --rule RA_reentrancyGuardStaysUnlocked --msg "silo RA_reentrancyGuardStaysUnlocked"  
certoraRun certora/config/silo/risk_assessment_silo.conf --server staging --rule onlyTrustedSender --msg "silo onlyTrustedSender"  

certoraRun certora/config/silo/risk_assessment_silo.conf --server staging --rule RA_reentrancyGuardStaysUnlocked --msg "silo RA_reentrancyGuardStaysUnlocked"