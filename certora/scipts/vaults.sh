# TODO failing rules:
# ? Timelock: https://prover.certora.com/output/40302/1de674d806dd40839e5f99ee6dafd325?anonymousKey=541f9a1fd8d34f2b6f6bbca1110bac56c68d73b3
# zero assets withdraw is possible on reallocate (MarketInteractions): https://prover.certora.com/output/40302/f691740242bb40bf9038484d70855aa9?anonymousKey=4218ebdab3fd49d95388c29c610fd2dcce8cbbb7

if [[ $CERTORA_PATH -eq "" ]]; then
    echo "CERTORA_PATH env variable is not set. Example '/Users/user/Library/Python/3.10/lib/python/site-packages/certora_cli/certoraRun.py'"
    exit 127
fi

# copy all contracts to harness folder
cp -r silo-vaults/contracts certora/harness/vaults
# apply patch to add useful state variables
git apply certora/scipts/MetaMorphoCertora.patch

# run Certora for every config
for configName in certora/config/vaults/*; do 
echo "Bash script is running Certora for $configName"
python3 $CERTORA_PATH $configName --solc /Library/Frameworks/Python.framework/Versions/3.10/bin/solc
done


