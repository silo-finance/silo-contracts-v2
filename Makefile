# Invariants
echidna:
	echidna silo-core/test/invariants/Tester.t.sol --contract Tester --config ./silo-core/test/invariants/_config/echidna_config.yaml --corpus-dir ./silo-core/test/invariants/_corpus/echidna/default/_data/corpus

echidna-assert:
	echidna silo-core/test/invariants/Tester.t.sol --contract Tester --test-mode assertion --config ./silo-core/test/invariants/_config/echidna_config.yaml --corpus-dir ./silo-core/test/invariants/_corpus/echidna/default/_data/corpus

echidna-explore:
	echidna silo-core/test/invariants/Tester.t.sol --contract Tester --test-mode exploration --config ./silo-core/test/invariants/_config/echidna_config.yaml --corpus-dir ./silo-core/test/invariants/_corpus/echidna/default/_data/corpus


# Medusa
medusa:
	medusa fuzz --config ./medusa.json

# Invariants
echidna-vaults:
	echidna silo-vaults/test/enigma-dark-invariants/Tester.t.sol --contract Tester --config ./silo-vaults/test/enigma-dark-invariants/_config/echidna_config.yaml

echidna-assert-vaults:
	echidna silo-vaults/test/enigma-dark-invariants/Tester.t.sol --contract Tester --test-mode assertion --config ./silo-vaults/test/enigma-dark-invariants/_config/echidna_config.yaml

echidna-explore-vaults:
	echidna silo-vaults/test/enigma-dark-invariants/Tester.t.sol --contract Tester --test-mode exploration --config ./silo-vaults/test/enigma-dark-invariants/_config/echidna_config.yaml

