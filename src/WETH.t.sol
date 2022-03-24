// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../lib/ds-test/src/test.sol";
import "./Utility.sol";

// Import interface.
import { IWETH } from "./interfaces/ERC20.sol";

contract WETHTest is Utility {

    event LogUint(string s, uint u);
    IWETH internal i_weth;
    

    // Deploy token, specify input params.
    // setUp() runs before every tests conduct.
    function setUp() public {
        emit LogUint('eth_bal', address(this).balance);
        i_weth = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    }

    function test_weth() public {
        uint bal = i_weth.balanceOf(
            0xE78388b4CE79068e89Bf8aA7f218eF6b9AB0e9d0
        );
        emit LogUint('bal_avax_bridge', bal);
        
    }


}