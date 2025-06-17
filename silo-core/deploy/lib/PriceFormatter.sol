// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Vm} from "forge-std/Vm.sol";

library PriceFormatter {
    /// @dev Cheat code address, 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D.
    address internal constant VM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));

    /// @dev Virtual machine instance
    Vm internal constant vm = Vm(VM_ADDRESS);

    function formatNumberInE(uint256 _in) internal pure returns (string memory) {
        if (_in < 1e3) return vm.toString(_in);

        uint256 e;
        uint256 out = _in;

        while (out != 0) {
            if (out % 10 != 0) break;

            e++;
            out /= 10;
        }

        if (e < 3 || _in < 1e6) return string.concat(vm.toString(_in), digits(_in));

        return string.concat(vm.toString(out), "e", vm.toString(e), digits(_in));
    }

    function formatPriceInE18(uint256 _in) internal pure returns (string memory) {
        if (_in < 1e4) return string.concat(vm.toString(_in), digits(_in));
        if (_in < 1e7) return formatNumberInE(_in);

        uint256 integerPart = _in / 1e18;
        uint256 fractionalPart = _in % 1e18;

        string memory integerStr = vm.toString(integerPart);
        uint256 leadingZeros = 18 - bytes(vm.toString(fractionalPart)).length;

        while (fractionalPart != 0 && fractionalPart % 10 == 0) {
            fractionalPart /= 10;
        }

        string memory fractionalStr = vm.toString(fractionalPart);

        for (uint256 i = 0; i < leadingZeros; i++) {
            fractionalStr = string.concat("0", fractionalStr);
        }

        if (integerPart == 0) {
            return string.concat("0.", fractionalStr, "e18");
        } if (fractionalPart == 0) {
            return string.concat(integerStr, "e18");
        } else {
            return string.concat(integerStr, ".", fractionalStr, "e18");
        }
    }

    function digits(uint256 _in) internal pure returns (string memory) {
        uint256 l = bytes(vm.toString(_in)).length;
        if (l < 6) return "";

        return string.concat(" [", vm.toString(l) ," digits]");
    }
}
