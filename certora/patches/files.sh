#!/bin/bash

# get rid of toHexString
file1_origin="silo-core/contracts/incentives/SiloIncentivesController.sol"
file1_munged="certora/patches/SiloIncentivesController.sol"
patch1_path="certora/patches/SiloIncentivesController.patch"
