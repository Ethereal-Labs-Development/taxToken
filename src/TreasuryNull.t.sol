// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../lib/ds-test/src/test.sol";
import "./Utility.sol";

// Import sol file
import "./TaxToken.sol";
import "./Treasury.sol";

// Import interface.
import { IERC20, IUniswapV2Router01, IWETH } from "./interfaces/ERC20.sol";

contract TreasuryNullTest is Utility {

    // State variable for contract.
    TaxToken taxToken;
    Treasury treasury;
    address UNIV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address UNIV2_PAIR = 0xf1d107ac566473968fC5A90c9EbEFe42eA3248a4;

    event LogUint(string s, uint u);
    event LogArrUint(string s, uint[] u);

    // Deploy token, specify input params.
    // setUp() runs before every tests conduct.
    function setUp() public {

        // Token instantiation.
        taxToken = new TaxToken(
            1000000000,                 // Initial liquidity
            'ProveZero',                // Name of token.
            'PROZ',                     // Symbol of token.
            18,                         // Precision of decimals.
            1000000,                    // Max wallet size
            100000                      // Max transaction amount
        );

        treasury = new Treasury(
            address(this), address(taxToken)
        );

        taxToken.setTreasury(address(treasury));


        // Set basisPointsTax for taxType 0 / 1 / 2
        // taxType 0 => Xfer Tax (10%)  => 10% (1wallets, marketing)
        // taxType 1 => Buy Tax (12%)   => 6%/6% (2wallets, use/marketing))
        // taxType 2 => Sell Tax (15%)  => 5%/4%/6% (3wallets, use/marketing/staking)
        taxToken.adjustBasisPointsTax(0, 1000);   // 1000 = 10.00 %
        taxToken.adjustBasisPointsTax(1, 1200);   // 1200 = 12.00 %
        taxToken.adjustBasisPointsTax(2, 1500);   // 1500 = 15.00 %

    }

    // Initial state check on treasury.
    // Each taxType (0, 1, and 2) should have some greater than 0 value.
    // The sum of all taxes accrued for each taxType should equal taxToken.balanceOf(treasury).
    // function test_treasury_initialState() public {
    //    //TODO: Test withdrawing funds ect with an empty treasury
    // }

}