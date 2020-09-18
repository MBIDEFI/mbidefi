// SPDX-License-Identifier: SimPL-2.0
pragma solidity ^0.7.0;

library SafeMath {
    // 乘
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    // 除
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b > 0);
        uint256 c = a / b;
        assert(a == b * c + (a % b));
        return c;
    }

    // 减
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    // 加
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a && c >= b);
        return c;
    }

    function indexOf(uint256[] memory self, uint256 value)
        internal
        pure
        returns (uint256)
    {
        for (uint256 i = 0; i < self.length; i++)
            if (self[i] == value) return i;
        return uint256(-1);
    }

    function indexOfAddress(address[] memory self, address value)
        internal
        pure
        returns (uint256)
    {
        for (uint256 i = 0; i < self.length; i++)
            if (self[i] == value) return i;
        return uint256(-1);
    }
}
