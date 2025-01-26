if [[ $CERTORA_PATH -eq "" ]]; then
    echo "CERTORA_PATH env variable is not set. Example '/Users/user/Library/Python/3.10/lib/python/site-packages/certora_cli/certoraRun.py'"
    exit 127
fi

# remove all existing contracts from harness folder
rm -r certora/harness/vaults/contracts/*
# copy all contracts to harness folder
cp -r silo-vaults/contracts certora/harness/vaults
# apply patch to add useful state variables
git apply certora/scipts/MetaMorphoCertora.patch

# run Certora for every config
for configName in certora/config/vaults/*; do 
echo "Bash script is running Certora for $configName"
python3 $CERTORA_PATH $configName --solc /Library/Frameworks/Python.framework/Versions/3.10/bin/solc
done


