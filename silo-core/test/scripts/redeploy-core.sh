git clean -fd silo-core/deployments
git clean -fd silo-core/broadcast
git clean -fd silo-oracles/deployments
git clean -fd silo-oracles/broadcast
git checkout -- silo-oracles/deploy/_oraclesDeployments.json
git checkout -- silo-core/deploy/silo/_siloDeployments.json

source ./.env

FOUNDRY_PROFILE=core \
    forge script silo-core/deploy/MainnetDeploy.s.sol \
    --ffi --broadcast --rpc-url $SILO_DEPLOYMENT_NODE
