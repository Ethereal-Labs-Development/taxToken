// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../lib/ds-test/src/test.sol";
import "./Utility.sol";

// Import sol file
import "./TaxToken.sol";
import "./Treasury.sol";

// Import interface.
import { IERC20 } from "./interfaces/ERC20.sol";

contract TaxTokenTest is Utility {

    // State variable for contract.
    TaxToken taxToken;
    Treasury treasury;

    // Deploy token, specify input params.
    // setUp() runs before every tests conduct.
    function setUp() public {
        taxToken = new TaxToken(
            1000 ether,                 // Initial liquidity
            'Darpa',                    // Name of token.
            'DRPK',                     // Symbol of token.
            18,                         // Precision of decimals.
            10,                         // Max transaction amount 
            address(this)               // The "owner" / "admin" of the contract.
        );

        treasury = new Treasury(
            address(this), address(taxToken)
        );

        taxToken.setTreasury(address(treasury));

        // TODO: Instantiate the tax basis rates for Type 0, 1, and 2.
        taxToken.adjustBasisPointsTax(0, 10000); // 10.00 %
    }

}