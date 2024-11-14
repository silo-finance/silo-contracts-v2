#!/bin/bash

git clean -fd ve-silo/deployments
git clean -fd silo-core/deployments
git clean -fd silo-core/broadcast
git clean -fd silo-oracles/deployments
git clean -fd silo-oracles/broadcast
git checkout -- silo-oracles/deploy/_oraclesDeployments.json
git checkout -- silo-core/deploy/silo/_siloDeployments.json
git checkout -- silo-core/deployments/arbitrum_one
git checkout -- silo-core/deployments/optimism
git checkout -- ve-silo/deployments/arbitrum_one
git checkout -- ve-silo/deployments/optimism
git checkout -- silo-oracles/deployments/arbitrum_one
git checkout -- silo-oracles/deployments/optimism
    