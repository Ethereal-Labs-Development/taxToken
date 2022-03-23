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
            1000 ether,
            'Darpa',
            'DRPK',
            18,
            address(this)
        );

        treasury = new Treasury(
            address(this), address(taxToken)
        );

        taxToken.setTreasury(address(treasury));

        // TODO: Instantiate the tax basis rates for Type 0, 1, and 2.
        taxToken.adjustBasisPointsTax(0, 10000); // 10.00 %
    }

    // TODO: Add more specific test-cases (pre-state / post-state).
    function test_simple_transfer_taxType_0() public {
        taxToken.transfer(address(0), 1 ether);
    }

    function test_simple_stateVariables() public {
        assertEq(1000 ether, taxToken.totalSupply());
        assertEq('Darpa', taxToken.name());
        assertEq('DRPK', taxToken.symbol());
        assertEq(18, taxToken.decimals());
        assertEq(taxToken.balanceOf(address(this)), taxToken.totalSupply());
        assertEq(taxToken.treasury(), address(treasury));
    }

    function testFail_simple_owner_modifer() public {
        assertEq(address(this), taxToken.owner());
        taxToken.transferOwnership(
            0xD533a949740bb3306d119CC777fa900bA034cd52
        );
        taxToken.transferOwnership(
            0x62B9c7356A2Dc64a1969e19C23e4f579F9810Aa7
        );
    }

    function test_simple_ownership_change() public {
        assertEq(address(this), taxToken.owner());
        taxToken.transferOwnership(
            0xD533a949740bb3306d119CC777fa900bA034cd52
        );
        assertEq(
            0xD533a949740bb3306d119CC777fa900bA034cd52, 
            taxToken.owner()
        );
    }

    // 10% Tax on Transactions
    // Transfer between any two wallets.
    // Buy, sell from liquidity pool.
}