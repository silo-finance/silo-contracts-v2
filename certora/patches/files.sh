#!/bin/bash

#1 get rid of toHexString
file1_origin="silo-core/contracts/incentives/SiloIncentivesController.sol"
file1_munged="certora/patches/SiloIncentivesController.sol"
patch1_path="certora/patches/SiloIncentivesController.patch"

#2 consequence of #1: put getProgramId out of use (at least in one place that I observed being visited)
file2_origin="silo-core/contracts/incentives/base/BaseIncentivesController.sol"
file2_munged="certora/patches/BaseIncentivesController.sol"
patch2_path="certora/patches/BaseIncentivesController.patch"

