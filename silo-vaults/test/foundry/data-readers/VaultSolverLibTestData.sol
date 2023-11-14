// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin-contracts/utils/Strings.sol";


contract VaultSolverLibTestData is Test {
    // must be in alphabetic order
    struct SilosDatas {
        uint256 borrow;
        uint256 deposit;
        uint256 expectedS;
        uint256 ucrit;
        uint256 uopt;
    }

    struct VaultSolverLibData {
        uint256 amountToDistribute; // Stot ?
        SilosDatas[] data;
        uint256 id;
        uint256 numberOfBaskets;
    }

    function _readDataFromJson() internal view returns (VaultSolverLibData[] memory) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/silo-vaults/test/foundry/data/VaultSolverLibData.json");
        string memory json = vm.readFile(path);

        return abi.decode(vm.parseJson(json, string(abi.encodePacked("."))), (VaultSolverLibData[]));
    }

    function _print(VaultSolverLibData memory _silosData) internal {
        emit log_named_uint("ID#", _silosData.id);
        emit log_named_uint("amountToDistribute", _silosData.amountToDistribute);
        emit log_named_uint("numberOfBaskets", _silosData.numberOfBaskets);
        emit log_named_uint("--------- data", _silosData.data.length);

        for (uint256 i; i < _silosData.data.length; i++) {
            emit log_named_uint(string.concat("deposit[", Strings.toString(i), "]"), _silosData.data[i].deposit);
            emit log_named_uint(string.concat("borrow[", Strings.toString(i), "]"), _silosData.data[i].borrow);
            emit log_named_uint(string.concat("ucrit[", Strings.toString(i), "]"), _silosData.data[i].ucrit);
            emit log_named_uint(string.concat("uopt[", Strings.toString(i), "]"), _silosData.data[i].uopt);
            emit log_named_uint(string.concat("expectedS[", Strings.toString(i), "]"), _silosData.data[i].expectedS);
        }
    }
}
