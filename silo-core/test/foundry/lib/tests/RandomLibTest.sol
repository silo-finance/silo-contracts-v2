import {Test} from "forge-std/Test.sol";
import {RandomLib} from "../../_common/RandomLib.sol";

/*
FOUNDRY_PROFILE=core_test forge test --mc RandomLibTest -vv
*/
contract RandomLibTest is Test {
    using RandomLib for uint256;

    function setUp() public {
        vm.startPrank(address(0x1));
    }

    function test_randomInside(uint256 _n, uint256 _min, uint256 _max) public pure {
        vm.assume(_min < type(uint256).max - 1);
        vm.assume(_min + 1 < _max);

        uint256 result = _n.randomInside(_min, _max);
        assertTrue(_min < result && result < _max, "randomInside fail");
    }

    function test_randomBetween(uint256 _n, uint256 _min, uint256 _max) public pure {
        vm.assume(_min <= _max);

        uint256 result = _n.randomBetween(_min, _max);
        assertTrue(_min <= result && result <= _max, "randomBetween fail");
    }

    function test_randomAbove(uint256 _n, uint256 _min, uint256 _max) public pure {
        vm.assume(_min < _max);

        uint256 result = _n.randomAbove(_min, _max);
        assertTrue(_min < result && result <= _max, "randomAbove fail");
    }

    function test_randomBelow(uint256 _n, uint256 _min, uint256 _max) public pure {
        vm.assume(_min < _max);

        uint256 result = _n.randomBelow(_min, _max);
        assertTrue(_min <= result && result < _max, "randomBelow fail");
    }
}
