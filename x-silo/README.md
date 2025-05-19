
## Coverage Report


```shell
brew install lcov

rm lcov.info
mkdir coverage

FOUNDRY_PROFILE=x_silo_tests forge coverage --report summary --report lcov --gas-price 1 --ffi --gas-limit 40000000000 --no-match-test "_skip_|_gas_|_anvil_" > coverage/x-silo.log
cat coverage/x-silo.log | grep -i 'x-silo/contracts/' > coverage/x-silo.txt
genhtml --ignore-errors inconsistent -ignore-errors range -o coverage/x-silo/ lcov.info
```
