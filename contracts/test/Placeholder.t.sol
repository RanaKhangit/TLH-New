// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/Placeholder.sol";

contract PlaceholderTest is Test {
    function test_ping_returns_true() public {
        Placeholder p = new Placeholder();
        assertTrue(p.ping());
    }
}
