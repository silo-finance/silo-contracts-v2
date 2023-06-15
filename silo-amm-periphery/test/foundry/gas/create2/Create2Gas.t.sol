// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "./PairCreate2.sol";

contract Factory {
    mapping(address => mapping(address => mapping(address => address))) internal _pairs;

    constructor(address _pair) {
        _pairs[msg.sender][address(1)][address(2)] = _pair;
    }

    function get(address _a, address _b, address _c) public view returns (address) {
        return _pairs[_a][_b][_c];
    }
}

contract Pair {
    address public constant token0 = address(1);
    address public constant token1 = address(2);
    address public constant silo = address(3);

    function get() public pure returns (bytes32) {
        // reading 3 slots
        return keccak256(abi.encode(token0, token1, silo));
    }
}

/*
    FOUNDRY_PROFILE=amm-periphery forge test -vv --match-contract Create2GasTest
*/
contract Create2GasTest is Test {
    bytes32 constant INIT_HASH = bytes32(0x3858a74580d233bea7420d0f6383ad8499ac270275d9fe840c13a653949d4742);

    PairCreate2 immutable pair2;
    Factory immutable factory;

    constructor() {
        Pair pair = new Pair();
        pair2 = PairCreate2(_deploy(address(1), address(2)));
        factory = new Factory(address(pair));
    }

    /*
        FOUNDRY_PROFILE=amm forge test -vvv --match-test test_Create2Gas_create2
    */
    function test_Create2Gas_create2() public {
        address token0 = address(1);
        address token1 = address(2);

        bytes32 codeHash = keccak256(abi.encodePacked(type(PairCreate2).creationCode));
        emit log_named_bytes32("init hash2", codeHash);
        assertEq(codeHash, INIT_HASH, "please update init hash");

        uint256 gasStart = gasleft();
        address calculatedPair = pairFor(address(this), token0, token1);
        bytes32 hash2 = PairCreate2(calculatedPair).get();
        uint256 gasEnd = gasleft();

        uint256 create2gas = gasStart - gasEnd;
        emit log_named_uint("create2gas + regular storage read 3x", create2gas);
        emit log_named_bytes32("hash", hash2);

        gasStart = gasleft();
        Pair pair = Pair(factory.get(address(this), token0, token1)); // .get() uses 5800 gas
        bytes32 hash = pair.get();
        gasEnd = gasleft();

        uint256 externalCallGas = gasStart - gasEnd;

        emit log_named_uint("externalCallGas + 3 constants", externalCallGas);
        emit log_named_bytes32("hash", hash);

        emit log_named_uint("with only 3 slot reads regular getter is less gas by", create2gas - externalCallGas);

        assertTrue(externalCallGas < create2gas);
    }

    function pairFor(address _factory, address _token0, address _token1) internal pure returns (address pair) {
        pair = address(uint160(uint(keccak256(abi.encodePacked(
            hex'ff',
            _factory,
            keccak256(abi.encodePacked(_token0, _token1)),
            INIT_HASH // init code hash
        )))));
    }

    function _deploy(address _token0, address _token1) internal returns (address pair) {
        bytes memory bytecode = type(PairCreate2).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(_token0, _token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
    }
}
