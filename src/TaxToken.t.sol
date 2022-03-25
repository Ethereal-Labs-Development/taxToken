// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../lib/ds-test/src/test.sol";
import "./Utility.sol";
import "./TaxToken.sol";
import "./Treasury.sol";

import { IERC20 } from "./interfaces/ERC20.sol";

contract TaxTokenTest is Utility {

    TaxToken taxToken;
    Treasury treasury;

    // setUp() runs before every single test-case.
    // Each test case uses a new/initial state each time based on actions here.
    function setUp() public {

        // taxToken constructor
        taxToken = new TaxToken(
            1000 ether,                 // Initial liquidity
            'Darpa',                    // Name of token.
            'DRPK',                     // Symbol of token.
            18,                         // Precision of decimals.
            address(this)               // The "owner" / "admin" of the contract.
        );

        // TODO: Instantiate the tax basis rates for Type 0, 1, and 2.
        treasury = new Treasury(address(this), address(taxToken));
        taxToken.setTreasury(address(treasury));
        taxToken.adjustBasisPointsTax(0, 10000); // 10.00 %
    }

    // TODO: Add more specific test-cases (pre-state / post-state).
    function test_simple_transfer_taxType_0() public {
        taxToken.transfer(address(0), 1 ether);
    }

    // Test initial state of state variables.
    function test_simple_stateVariables() public {
        assertEq(1000 ether, taxToken.totalSupply());
        assertEq('Darpa', taxToken.name());
        assertEq('DRPK', taxToken.symbol());
        assertEq(18, taxToken.decimals());
        assertEq(taxToken.balanceOf(address(this)), taxToken.totalSupply());
        assertEq(taxToken.treasury(), address(treasury));
    }

    // Test onlyOwner() modifier, confirm one function fails when caller is not msg.sender.
    function testFail_simple_owner_modifer() public {
        assertEq(address(this), taxToken.owner());
        taxToken.transferOwnership(
            0xD533a949740bb3306d119CC777fa900bA034cd52
        );
        taxToken.transferOwnership(
            0x62B9c7356A2Dc64a1969e19C23e4f579F9810Aa7
        );
    }

    // Test transferOwnership().
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

    // Test permanentlyRemoveTaxes() fail case, where input != 42.
    function testFail_remove_taxes_permanently() public {
        taxToken.permanentlyRemoveTaxes(41);
    }

    // Test permanentlyRemoveTaxes() success case, taxes are 0 for the 3 explicit tax types (0, 1, 2).
    function test_remove_taxes_permanently() public {
        taxToken.permanentlyRemoveTaxes(42);
        assertEq(taxToken.basisPointsTax(0), 0);
        assertEq(taxToken.basisPointsTax(1), 0);
        assertEq(taxToken.basisPointsTax(2), 0);
        assertEq(taxToken.owner(), address(0));
    }


    // ~ ERC20 Pausable Tests ~

    // This tests is it's not possible to call transfer() when the contract is "paused".
    function testFail_pause_transfer() public {
        taxToken.pause();
        taxToken.transfer(address(42), 1 ether);
    }
    
    // This tests if contract is "paused" or "unpaused" after admin calls the pause() or unpause() functions.
    function test_pause_unpause() public {

        assert(!taxToken.paused());     // Initial state of contract is "not paused"

        taxToken.pause();
        assert(taxToken.paused());

        taxToken.unpause();
        assert(!taxToken.paused());

    }

    // ~ Blacklist Testing ~

    // This tests blacklisting of the receiver
    function testFail_blacklist_receiver() public {
        taxToken.transfer(address(32), 1 ether);
        taxToken.modifyBlacklist(address(32), true);
        taxToken.transfer(address(32), 1 ether);
    }

    // This tests blacklisting of the sender
    function testFail_blacklist_sender() public {
        taxToken.transfer(address(32), 1 ether);
        taxToken.modifyBlacklist(address(this), true);
        taxToken.transfer(address(32), 1 ether);
    }

}