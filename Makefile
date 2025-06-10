# Invariants
echidna-x-silo:
	echidna x-silo/test/echidna/XSiloTester.t.sol --contract XSiloTester --config ./x-silo/test/echidna/_config/echidna_config.yaml --corpus-dir ./x-silo/test/echidna/_corpus/echidna/default/_data/corpus/x-silo

echidna:
	echidna silo-core/test/invariants/Tester.t.sol --contract Tester --config ./silo-core/test/invariants/_config/echidna_config.yaml --corpus-dir ./silo-core/test/invariants/_corpus/echidna/default/_data/corpus

echidna-assert:
	echidna silo-core/test/invariants/Tester.t.sol --contract Tester --test-mode assertion --config ./silo-core/test/invariants/_config/echidna_config.yaml --corpus-dir ./silo-core/test/invariants/_corpus/echidna/default/_data/corpus

echidna-explore:
	echidna silo-core/test/invariants/Tester.t.sol --contract Tester --test-mode exploration --config ./silo-core/test/invariants/_config/echidna_config.yaml --corpus-dir ./silo-core/test/invariants/_corpus/echidna/default/_data/corpus


# Medusa
medusa:
	medusa fuzz --config ./medusa.json
