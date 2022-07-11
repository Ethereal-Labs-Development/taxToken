// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../../lib/ds-test/src/test.sol";
import "./Utility.sol";
import "../TaxToken.sol";
import "../Treasury.sol";

import { IERC20 } from "../interfaces/InterfacesAggregated.sol";

contract TaxTokenTest is Utility {

    // State variable for contract.
    TaxToken taxToken;
    Treasury treasury;


    // setUp() runs before every single test-case.
    // Each test case uses a new/initial state each time based on actions here.
    function setUp() public {
        createActors();

        // taxToken constructor
        taxToken = new TaxToken(
            1000,       // Initial liquidity
            'Darpa',    // Name of token.
            'DRPK',     // Symbol of token.
            18,         // Precision of decimals.
            100,        // Max wallet size
            10          // Max transaction amount
        );

        // TODO: Instantiate the tax basis rates for Type 0, 1, and 2.
        treasury = new Treasury(address(this), address(taxToken));
        taxToken.setTreasury(address(treasury));
        taxToken.adjustBasisPointsTax(0, 1000);   // 1000 = 10.00 %
    }

    // Test initial state of state variables.
    function test_simple_stateVariables() public {
        assertEq(1000 ether, taxToken.totalSupply());
        assertEq('Darpa', taxToken.name());
        assertEq('DRPK', taxToken.symbol());
        assertEq(18, taxToken.decimals());
        assertEq((100 * 10**18), taxToken.maxWalletSize());
        assertEq((10 * 10**18), taxToken.maxTxAmount());
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

    // Test adjustBasisPointsTax and ensure it is impossible to set basis tax over 20%.
    function testFail_adjustBasisPointsTax_aboveMax() public {
        taxToken.adjustBasisPointsTax(0, 2100);
    }

    // Test permanentlyRemoveTaxes() success case, taxes are 0 for the 3 explicit tax types (0, 1, 2).
    function test_remove_taxes_permanently() public {
        taxToken.permanentlyRemoveTaxes(42);
        assertEq(taxToken.basisPointsTax(0), 0);
        assertEq(taxToken.basisPointsTax(1), 0);
        assertEq(taxToken.basisPointsTax(2), 0);
    }

    // Test permanentlyRemoveTaxes() that it is impossible to call adjustBasisPoints() afterwards.
    function testFail_remove_taxes_adjust() public {
        taxToken.permanentlyRemoveTaxes(42);
        taxToken.adjustBasisPointsTax(0, 1000);
    }


    // ~ ERC20 Pausable Tests ~

    // This tests is it's not possible to call transfer() when the contract is "paused".
    function testFail_pause_transfer() public {
        taxToken.pause();
        taxToken.transfer(address(42), 1 ether);
    }
    
    // This tests if contract is "paused" or "unpaused" after admin calls the pause() or unpause() functions.
    function test_pause_unpause() public {
        assert(!taxToken.paused());     // Initial state of contract is "not paused".

        taxToken.pause();
        assert(taxToken.paused());

        taxToken.unpause();
        assert(!taxToken.paused());

    }

    // ~ Blacklist Testing ~

    // This tests blacklisting of the receiver.
    function test_blacklist_receiver() public {
        taxToken.transfer(address(32), 1 ether);
        taxToken.modifyBlacklist(address(32), true);
        assert(!taxToken.transfer(address(32), 1 ether));
    }

    // This tests blacklisting of the sender.
    function test_blacklist_sender() public {
        taxToken.transfer(address(32), 1 ether);
        taxToken.modifyBlacklist(address(this), true);
        assert(!taxToken.transfer(address(32), 1 ether));
    }

    // This tests that a blacklisted wallet can only make transfers to a whitelisted wallet
    function test_blacklist_whitelist() public {
        // this contract can successfully send assets to address(32)
        assert(taxToken.transfer(address(32), 1 ether));

        // blacklist this contract
        taxToken.modifyBlacklist(address(this), true);

        // This contract can no longer send tokens to address(32)
        assert(!taxToken.transfer(address(32), 1 ether));

        // Whitelist address(32)
        taxToken.modifyWhitelist(address(32), true);

        // this contract can successfully send assets to whitelisted address(32)
        assert(taxToken.transfer(address(32), 1 ether));
    }

    // ~ Whitelist Testing ~

    // This tests whether a transfer is taxed when the receiver is whitelisted.
    function test_whitelist_transfer() public {
        taxToken.modifyWhitelist(address(69), true);
        taxToken.transfer(address(69), 1 ether);
    }

    // This tests once a whitelisted wallet calls a transfer, they receive the full amount of tokens.
    function test_whitelist_balance() public {
        taxToken.modifyWhitelist(address(69), true);
        taxToken.transfer(address(69), 1 ether);
        assertEq(taxToken.balanceOf(address(69)), 1 ether);
    }

    // ~ Restrictive functions Testing (Non-Whitelisted) ~

    // Test changing maxWalletSize.
    function test_updateMaxWalletSize() public {
        taxToken.updateMaxWalletSize(300);
        assertEq((300 * 10**18), taxToken.maxWalletSize());
    }

    // Test updating a transfer amount.
    function test_updateMaxTxAmount() public {
        taxToken.updateMaxTxAmount(30);
        assertEq((30 * 10**18), taxToken.maxTxAmount());
    }

    // Test a transfer amount greater than the maxTxAmount NON Whitelisted.
    function testFail_MaxTxAmount_sender() public {
        taxToken.modifyWhitelist(address(70), false);
        assert(taxToken.transfer(address(70), 11 ether));
    }

    // Test adding an amount greater than the maxWalletAmount.
    function testFail_MaxWalletAmount_sender() public {
        taxToken.modifyWhitelist(address(70), false);
        taxToken.transfer(address(70), 10 ether);
        taxToken.transfer(address(70), 10 ether);
        taxToken.transfer(address(70), 10 ether);
        taxToken.transfer(address(70), 10 ether);
        taxToken.transfer(address(70), 10 ether);
        taxToken.transfer(address(70), 10 ether);
        taxToken.transfer(address(70), 10 ether);
        taxToken.transfer(address(70), 10 ether);
        taxToken.transfer(address(70), 10 ether);
        taxToken.transfer(address(70), 10 ether);
        taxToken.transfer(address(70), 10 ether);
        assert(taxToken.transfer(address(70), 10 ether));
    }

    // ~ Restrictive functions Testing (Whitelisted) ~
    
    // Test a transfer amount greater than the maxTxAmount Whitelisted.
    function test_WLMaxTxAmount_sender() public {
        taxToken.modifyWhitelist(address(70), true);
        assert(taxToken.transfer(address(70), 11 ether));
    }

    // Test adding an amount greater than the maxWalletAmount.
    function test_WLMaxWalletAmount_sender() public {
        taxToken.transfer(address(70), 10 ether);
        taxToken.transfer(address(70), 10 ether);
        taxToken.transfer(address(70), 10 ether);
        taxToken.transfer(address(70), 10 ether);
        taxToken.transfer(address(70), 10 ether);
        taxToken.transfer(address(70), 10 ether);
        taxToken.transfer(address(70), 10 ether);
        taxToken.transfer(address(70), 10 ether);
        taxToken.transfer(address(70), 10 ether);
        taxToken.transfer(address(70), 10 ether);
        taxToken.transfer(address(70), 10 ether);
        taxToken.modifyWhitelist(address(70), true);
        assert(taxToken.transfer(address(70), 10 ether));
    }

    // ~ Taxt Type 0 Testing ~

    // Test taking a tax of type 0 from a transfer.
    function test_TaxOnTransfer() public {
        taxToken.transfer(address(15), 10 ether);
        assertEq(taxToken.balanceOf(address(15)), 9 ether);
    }

    // Test taking a tax of type 0 from a transfer when the wallet is whitelisted.
    function testFail_TaxOnTransfer_WL() public {
        taxToken.modifyWhitelist(address(16), true);
        taxToken.transfer(address(16), 10 ether);
        assertEq(taxToken.balanceOf(address(16)), 9 ether);
    }

    // Verify that we cannot blacklist a whitelisted wallet.
    function testFail_blacklistWhitelistedWallet() public {
        taxToken.modifyBlacklist(address(treasury), true);
    }

    // ~ mint() Testing ~

    // Test mint() to admin
    function test_mint() public {
        taxToken.transferOwnership(address(god));

        // Pre-state check.
        assertEq(taxToken.balanceOf(address(god)), 0);
        assertEq(taxToken.totalSupply(), 1000 ether);

        // Mint 10 tokens to admin.
        assert(god.try_mint(address(taxToken), address(god), 10 ether));

        //Post-state check.
        assertEq(taxToken.balanceOf(address(god)), 10 ether);
        assertEq(taxToken.totalSupply(), 1010 ether);
    }

    function test_industryMint() public {
        taxToken.transferOwnership(address(god));

        // Pre-state check.
        assertEq(taxToken.balanceOf(address(god)), 0);
        assertEq(taxToken.totalSupply(), 1000 ether);

        // Mint 10 tokens to joe.
        assert(god.try_mint(address(taxToken), address(joe), 10 ether));

        // Mint 10 tokens to joe.
        assert(god.try_industryMint(address(taxToken), address(joe), 10 ether));

        //Post-state check.
        assertEq(taxToken.balanceOf(address(joe)), 20 ether);
        assertEq(taxToken.industryTokens(address(joe)),10 ether);
        assertEq(taxToken.lifeTimeIndustryTokens(address(joe)),10 ether);
        assertEq(taxToken.totalSupply(), 1020 ether);

        // Mint 10 tokens to joe.
        assert(god.try_industryMint(address(taxToken), address(joe), 10 ether));

    }

    // Test mint() by a non-admin
    function test_malicousMint() public {
        // Joe attempts to mint himself tokens
        assert(!joe.try_mint(address(taxToken), address(joe), 10 ether));
    }

    //TODO: Test sending restrictions
    //TODO: Test burning restrictions

    // ~ burn() Testing ~

    // Test burn() from admin
    function test_burn() public {
        taxToken.transferOwnership(address(god));
        assert(god.try_mint(address(taxToken), address(god), 10 ether));

        // Pre-state check.
        assertEq(taxToken.balanceOf(address(god)), 10 ether);
        assertEq(taxToken.totalSupply(), 1010 ether);

        // Burn 10 tokens to admin.
        assert(god.try_burn(address(taxToken), address(god), 10 ether));

        //Post-state check.
        assertEq(taxToken.balanceOf(address(god)), 0 ether);
        assertEq(taxToken.totalSupply(), 1000 ether);
    }

    function test_industryBurn_noLocked() public {
        taxToken.transferOwnership(address(god));
        assert(god.try_mint(address(taxToken), address(god), 10 ether));

        // Pre-state check.
        assertEq(taxToken.balanceOf(address(god)), 10 ether);
        assertEq(taxToken.totalSupply(), 1010 ether);

        // Burn 10 tokens to admin.
        assert(god.try_industryBurn(address(taxToken), address(god), 10 ether));

        //Post-state check.
        assertEq(taxToken.balanceOf(address(god)), 0 ether);
        assertEq(taxToken.totalSupply(), 1000 ether);
    }

    function test_industryBurn_someLocked() public {
        taxToken.transferOwnership(address(god));
        assert(god.try_mint(address(taxToken), address(god), 10 ether));
        assert(god.try_industryMint(address(taxToken), address(god), 10 ether));

        // Pre-state check.
        assertEq(taxToken.balanceOf(address(god)), 20 ether);
        assertEq(taxToken.totalSupply(), 1020 ether);

        // Burn 10 tokens to admin.
        assert(god.try_industryBurn(address(taxToken), address(god), 15 ether));

        //Post-state check.
        assertEq(taxToken.balanceOf(address(god)), 5 ether);
        assertEq(taxToken.totalSupply(), 1005 ether);
    }

    function test_industryBurn_allLocked() public {
        taxToken.transferOwnership(address(god));
        assert(god.try_industryMint(address(taxToken), address(god), 10 ether));

        // Pre-state check.
        assertEq(taxToken.balanceOf(address(god)), 10 ether);
        assertEq(taxToken.totalSupply(), 1010 ether);

        // Burn 10 tokens to admin.
        assert(god.try_industryBurn(address(taxToken), address(god), 10 ether));

        //Post-state check.
        assertEq(taxToken.balanceOf(address(god)), 0 ether);
        assertEq(taxToken.totalSupply(), 1000 ether);
    }

    // Test burn() by a non-admin
    function test_malicousBurn() public {
        // Joe attempts to mint himself tokens
        assert(!joe.try_burn(address(taxToken), address(joe), 10 ether));
    }


}
