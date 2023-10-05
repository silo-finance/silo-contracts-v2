### BalancerMinter.sol
- Bumped solidity to 0.8.21 ([8443b28](https://github.com/silo-finance/silo-contracts-v2/commit/8443b286829f2bdba9181e5a764dd25a7906db13))

- Implemented FeesManager for the BalancerMinter ([cfbb406](https://github.com/silo-finance/silo-contracts-v2/pull/155/commits/cfbb4060b3e1c747797565e3e934faa0ec92ae03))

- Fees collection ([ad564c1](https://github.com/silo-finance/silo-contracts-v2/pull/97/commits/ad564c19f4fa0b3a2a2f741168a7880e18904449))

- solhint-disable ordering for BalancerMinter ([cfda647](https://github.com/silo-finance/silo-contracts-v2/pull/38/commits/cfda647e39e006a3c50a67792cae81368ccd9acb))

- Bumped solidity to 0.8.19 & updated imports ([de03bc0](https://github.com/silo-finance/silo-contracts-v2/pull/38/commits/de03bc0debbb4cc7bb25ec99d0250336a8cc02c8))

- Copy of Balancer's implementation of the BalancerMinter.sol ([01439b5](https://github.com/silo-finance/silo-contracts-v2/pull/38/commits/01439b5dcd336edf7866e4f633a192984756a210))

### BalancerTokenAdmin.sol
- Bumped solidity to 0.8.21 ([8443b28](https://github.com/silo-finance/silo-contracts-v2/commit/8443b286829f2bdba9181e5a764dd25a7906db13))

- Added  a possibility to stop a mining program by transferring ownership of the incentive token ([cb7b755](https://github.com/silo-finance/silo-contracts-v2/pull/93/commits/cb7b75505384e77cbb4431cc4eb15f53fea20a37))

- Changed ownership system for BalancerTokenAdmin. Replaced SingletonAuthentication with ExtendedOwnable ([47c8933](https://github.com/silo-finance/silo-contracts-v2/pull/38/commits/47c89333cebd0bb772f7da1b0bf2d76981c8a5a6))

- solhint-disable ordering for BalancerTokenAdmin ([a92a196](https://github.com/silo-finance/silo-contracts-v2/pull/38/commits/a92a19673b56acfeb78a44d6971916dd38a56c07))

- Bumped solidity to 0.8.19 & updated imports ([d064474](https://github.com/silo-finance/silo-contracts-v2/pull/38/commits/d064474905124d29b49feabba0cc22a9dc381487))

- Copy of Balancer's implementation of the BalancerTokenAdmin.sol ([44824ae](https://github.com/silo-finance/silo-contracts-v2/pull/38/commits/44824aeb22ca0bddcc87f109e19fce792984469c))

### MainnetBalancerMinter.sol
- Bumped solidity to 0.8.21 ([8443b28](https://github.com/silo-finance/silo-contracts-v2/commit/8443b286829f2bdba9181e5a764dd25a7906db13))

- Fees collection ([2767b4a](https://github.com/silo-finance/silo-contracts-v2/pull/97/commits/2767b4a2bf6d1db9473eaeacfa67d868a8c66e41))

- Updated interfaces as Balancer's implementations were not complete, and some methods that we need for test missed ([c23801c](https://github.com/silo-finance/silo-contracts-v2/pull/38/commits/c23801cdecf88e5b85f37ac39dc6e3f7817aa054))

- Bumped solidity to 0.8.19 & updated imports ([a44710c](https://github.com/silo-finance/silo-contracts-v2/pull/38/commits/a44710c33a7d791d9b02f77f35e339090b7a994f))

- Copy of Balancer's implementation of the MainnetBalancerMinter.sol ([c3762da](https://github.com/silo-finance/silo-contracts-v2/pull/38/commits/c3762da774abbab4a309157c86237c1432e01ae8))

### L2BalancerPseudoMinter.sol
- Bumped solidity to 0.8.21 ([8443b28](https://github.com/silo-finance/silo-contracts-v2/commit/8443b286829f2bdba9181e5a764dd25a7906db13))

- Removed Ownable2Step as it is now a part of the BalancerMinter.sol ([4c126b4](https://github.com/silo-finance/silo-contracts-v2/pull/155/commits/4c126b49282fc9b0930cb794f77178c6cbfc4a16))

- Fees collection ([6cbbfa0](https://github.com/silo-finance/silo-contracts-v2/pull/97/commits/6cbbfa0e629e6b686f322d89f87f244427dde5ee))

- Changed EIP712 name to `Silo Pseudo Minter` ([c7a308d](https://github.com/silo-finance/silo-contracts-v2/pull/62/commits/c7a308d2b8f547983ca8179ccb9f4c96b1248e91))

- Bumped solidity to 0.8.19, updated imports, solhint ([d738a00](https://github.com/silo-finance/silo-contracts-v2/pull/62/commits/d738a00897465e70f7284c5c3c11738242f45f56))

- Changed ownership system for L2BalancerPseudoMinter. Replaced SingletonAuthentication with ExtendedOwnable ([c21d7f2](https://github.com/silo-finance/silo-contracts-v2/pull/62/commits/c21d7f2ab24a8df01222389b5a44d693913cd355))

- Copy of Balancer's implementation of the L2BalancerPseudoMinter.sol ([4415ea1](https://github.com/silo-finance/silo-contracts-v2/pull/62/commits/4415ea1e19992f602104cd87d20609c565a2ef1d))