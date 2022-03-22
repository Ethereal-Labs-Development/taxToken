// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "ds-test/test.sol";

import "./Taxtoken.sol";

contract TaxtokenTest is DSTest {
    Taxtoken taxtoken;

    function setUp() public {
        taxtoken = new Taxtoken();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
