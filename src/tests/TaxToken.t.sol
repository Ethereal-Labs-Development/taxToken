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
            'TaxToken', // Name of token
            'TAX',      // Symbol of token
            18,         // Precision of decimals
            100,        // Max wallet size
            10          // Max transaction amount
        );

        // TODO: Instantiate the tax basis rates for Type 0, 1, and 2.
        treasury = new Treasury(address(this), address(taxToken));
        taxToken.setTreasury(address(treasury));
        taxToken.adjustBasisPointsTax(0, 1000);   // 1000 = 10.00 %
    }

    // Test initial state of state variables.
    function test_taxToken_simple_stateVariables() public {
        assertEq(1000 ether, taxToken.totalSupply());
        assertEq('TaxToken', taxToken.name());
        assertEq('TAX', taxToken.symbol());
        assertEq(18, taxToken.decimals());
        assertEq((100 * 10**18), taxToken.maxWalletSize());
        assertEq((10 * 10**18), taxToken.maxTxAmount());
        assertEq(taxToken.balanceOf(address(this)), taxToken.totalSupply());
        assertEq(taxToken.treasury(), address(treasury));
    }

    // Test onlyOwner() modifier and ensure old owners cannot call onlyOwner.
    function testFail_taxToken_simple_owner_modifer() public {
        //Verify original owner.
        assertEq(address(this), taxToken.owner());

        //Transfer Ownership to a different wallet.
        taxToken.transferOwnership(0xD533a949740bb3306d119CC777fa900bA034cd52);

        //Attempt to call owner only function with a now non-owner wallet.
        taxToken.transferOwnership(0x62B9c7356A2Dc64a1969e19C23e4f579F9810Aa7);
    }

    // Test transferOwnership().
    function test_taxToken_simple_ownership_change() public {
        //Verify original owner.
        assertEq(address(this), taxToken.owner());

        //Transfer ownership to a different wallet.
        taxToken.transferOwnership(0xD533a949740bb3306d119CC777fa900bA034cd52);

        //Verify new owner wallet is the same as the set wallet.
        assertEq(0xD533a949740bb3306d119CC777fa900bA034cd52, taxToken.owner());
    }

    // Test permanentlyRemoveTaxes() fail case, where input != 42.
    function testFail_taxToken_remove_taxes_permanently() public {
        taxToken.permanentlyRemoveTaxes(41);
    }

    // Test adjustBasisPointsTax and ensure it is impossible to set basis tax over 20%.
    function testFail_taxToken_adjustBasisPointsTax_aboveMax() public {
        // Attempt to set a tax at 21%.
        taxToken.adjustBasisPointsTax(0, 2100);
    }

    // Test permanentlyRemoveTaxes() success case, taxes are 0 for the 3 explicit tax types (0, 1, 2).
    function test_taxToken_remove_taxes_permanently() public {
        taxToken.permanentlyRemoveTaxes(42);
        assertEq(taxToken.basisPointsTax(0), 0);
        assertEq(taxToken.basisPointsTax(1), 0);
        assertEq(taxToken.basisPointsTax(2), 0);
    }

    // Test permanentlyRemoveTaxes() that it is impossible to call adjustBasisPoints() afterwards.
    function testFail_taxToken_remove_taxes_adjust() public {
        taxToken.permanentlyRemoveTaxes(42);
        taxToken.adjustBasisPointsTax(0, 1000);
    }


    // ~ ERC20 Pausable Tests ~

    // This tests is it's not possible to call transfer() when the contract is "paused".
    function testFail_taxToken_pause_transfer() public {
        taxToken.pause();
        taxToken.transfer(address(42), 1 ether);
    }
    
    // This tests if contract is "paused" or "unpaused" after admin calls the pause() or unpause() functions.
    function test_taxToken_pause_unpause() public {
        // Initial state of contract is "not paused".
        assert(!taxToken.paused());

        taxToken.pause();
        assert(taxToken.paused());

        taxToken.unpause();
        assert(!taxToken.paused());

    }

    // ~ Blacklist Testing ~

    // This tests blacklisting of the receiver.
    function test_taxToken_blacklist_receiver() public {
        taxToken.transfer(address(32), 1 ether);
        taxToken.modifyBlacklist(address(32), true);
        assert(!taxToken.transfer(address(32), 1 ether));
    }

    // This tests blacklisting of the sender.
    function test_taxToken_blacklist_sender() public {
        taxToken.transfer(address(32), 1 ether);
        taxToken.modifyBlacklist(address(this), true);
        assert(!taxToken.transfer(address(32), 1 ether));
    }

    // This tests that a blacklisted wallet can only make transfers to a whitelisted wallet.
    function test_taxToken_blacklist_whitelist() public {
        // This contract can successfully send assets to address(32).
        assert(taxToken.transfer(address(32), 1 ether));

        // Blacklist this contract.
        taxToken.modifyBlacklist(address(this), true);

        // This contract can no longer send tokens to address(32).
        assert(!taxToken.transfer(address(32), 1 ether));

        // Whitelist address(32).
        taxToken.modifyWhitelist(address(32), true);

        // This contract can successfully send assets to whitelisted address(32).
        assert(taxToken.transfer(address(32), 1 ether));
    }

    // ~ Whitelist Testing ~

    // This tests whether a transfer is taxed when the receiver is whitelisted.
    function test_taxToken_whitelist_transfer() public {
        taxToken.modifyWhitelist(address(69), true);
        taxToken.transfer(address(69), 1 ether);
    }

    // This tests once a whitelisted wallet calls a transfer, they receive the full amount of tokens.
    function test_taxToken_whitelist_balance() public {
        taxToken.modifyWhitelist(address(69), true);
        taxToken.transfer(address(69), 1 ether);
        assertEq(taxToken.balanceOf(address(69)), 1 ether);
    }

    // ~ Restrictive functions Testing (Non-Whitelisted) ~

    // Test changing maxWalletSize.
    function test_taxToken_updateMaxWalletSize() public {
        taxToken.updateMaxWalletSize(300);
        assertEq((300 * 10**18), taxToken.maxWalletSize());
    }

    // Test updating a transfer amount.
    function test_taxToken_updateMaxTxAmount() public {
        taxToken.updateMaxTxAmount(30);
        assertEq((30 * 10**18), taxToken.maxTxAmount());
    }

    // Test a transfer amount greater than the maxTxAmount NON Whitelisted.
    function testFail_taxToken_MaxTxAmount_sender() public {
        taxToken.modifyWhitelist(address(70), false);
        assert(taxToken.transfer(address(70), 11 ether));
    }

    // Test adding an amount greater than the maxWalletAmount.
    function testFail_taxToken_MaxWalletAmount_sender() public {
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
    function test_taxToken_WLMaxTxAmount_sender() public {
        taxToken.modifyWhitelist(address(70), true);
        assert(taxToken.transfer(address(70), 11 ether));
    }

    // Test adding an amount greater than the maxWalletAmount.
    function test_taxToken_WLMaxWalletAmount_sender() public {
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
    function testFail_taxToken_TaxOnTransfer_WL() public {
        taxToken.modifyWhitelist(address(16), true);
        taxToken.transfer(address(16), 10 ether);
        assertEq(taxToken.balanceOf(address(16)), 9 ether);
    }

    // Verify that we cannot blacklist a whitelisted wallet.
    function testFail_taxToken_blacklistWhitelistedWallet() public {
        taxToken.modifyBlacklist(address(treasury), true);
    }

    // ~ mint() Testing ~

    // Test mint() to admin.
    function test_taxToken_mint() public {
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

    // Test industryMint() state changes.
    function test_taxToken_industryMint() public {
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
        assertEq(taxToken.industryTokens(address(joe)), 10 ether);
        assertEq(taxToken.lifeTimeIndustryTokens(address(joe)), 10 ether);
        assertEq(taxToken.totalSupply(), 1020 ether);
    }

    // Test mint()/industryMint() restrictions.
    function test_taxToken_mint_restrictions() public {
        taxToken.transferOwnership(address(god));

        // Joe cannot mint tokens for himself.
        assert(!joe.try_mint(address(taxToken), address(joe), 10 ether));

        // Admin cannot perform a mint to address 0.
        assert(!god.try_mint(address(taxToken), address(0), 10 ether));

        // Admin can successfully perform a mint.
        assert(god.try_mint(address(taxToken), address(god), 10 ether));

        // Joe cannot industry mint tokens to himself.
        assert(!joe.try_industryMint(address(taxToken), address(joe), 10 ether));

        // Admin cannot perform an industry mint to address 0.
        assert(!god.try_industryMint(address(taxToken), address(0), 10 ether));

        // Admin can successfully perform an industry mint.
        assert(god.try_industryMint(address(taxToken), address(god), 10 ether));

    }

    // Test to see if you can send locked tokens.
    function test_taxToken_industryMint_restrictions() public {
        taxToken.transferOwnership(address(god));
        
        // Regular Mint Joe 10 tokens.
        assert(god.try_mint(address(taxToken), address(god), 10 ether));

        // Industry Mint Joe 10 tokens.
        assert(god.try_industryMint(address(taxToken), address(god), 10 ether));

        // Confirm Balances.
        assertEq(taxToken.balanceOf(address(god)), 20 ether);

        // Attempt to send 15 tokens.
        assert(!taxToken.transfer(address(god), 15 ether));

        // Confirm Balances didn't change.
        assertEq(taxToken.balanceOf(address(god)), 20 ether);

    }

    // ~ burn() Testing ~

    // Test burn() from admin.
    function test_taxToken_burn() public {
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

    // Test industryBurn with no locked tokens.
    function test_taxToken_industryBurn_noLocked() public {
        taxToken.transferOwnership(address(god));
        assert(god.try_mint(address(taxToken), address(god), 10 ether));
        assertEq(taxToken.industryTokens(address(god)), 0);

        // Pre-state check.
        assertEq(taxToken.balanceOf(address(god)), 10 ether);
        assertEq(taxToken.totalSupply(), 1010 ether);

        // Burn 10 tokens to admin.
        assert(god.try_industryBurn(address(taxToken), address(god), 10 ether));

        //Post-state check.
        assertEq(taxToken.balanceOf(address(god)), 0 ether);
        assertEq(taxToken.totalSupply(), 1000 ether);
        assertEq(taxToken.industryTokens(address(god)), 0);
    }

    // Test industryBurn with some locked tokens.
    function test_taxToken_industryBurn_someLocked() public {
        taxToken.transferOwnership(address(god));
        assert(god.try_mint(address(taxToken), address(god), 10 ether));
        assert(god.try_industryMint(address(taxToken), address(god), 10 ether));

        // Pre-state check.
        assertEq(taxToken.balanceOf(address(god)), 20 ether);
        assertEq(taxToken.totalSupply(), 1020 ether);
        assertEq(taxToken.industryTokens(address(god)), 10 ether);

        // Burn 10 tokens to admin.
        assert(god.try_industryBurn(address(taxToken), address(god), 15 ether));

        //Post-state check.
        assertEq(taxToken.balanceOf(address(god)), 5 ether);
        assertEq(taxToken.totalSupply(), 1005 ether);
        assertEq(taxToken.industryTokens(address(god)), 0);
    }

    // Test industryBurn with only locked tokens.
    function test_taxToken_industryBurn_allLocked() public {
        taxToken.transferOwnership(address(god));
        assert(god.try_industryMint(address(taxToken), address(god), 10 ether));

        // Pre-state check.
        assertEq(taxToken.balanceOf(address(god)), 10 ether);
        assertEq(taxToken.totalSupply(), 1010 ether);
        assertEq(taxToken.industryTokens(address(god)), 10 ether);

        // Burn 10 tokens to admin.
        assert(god.try_industryBurn(address(taxToken), address(god), 10 ether));

        //Post-state check.
        assertEq(taxToken.balanceOf(address(god)), 0 ether);
        assertEq(taxToken.totalSupply(), 1000 ether);
        assertEq(taxToken.industryTokens(address(god)), 0);
    }

    // Test burn()/industryBurn() restrictions.
    function test_taxToken_burn_restrictions() public {
        taxToken.transferOwnership(address(god));

        // Admin cannot burn tokens that don't exist.
        assert(!god.try_burn(address(taxToken), address(god), 10 ether));

        // Admin cannot burn tokens that don't exist.
        assert(!god.try_industryBurn(address(taxToken), address(god), 10 ether));


        // Admin will mint tokens for burn.
        assert(god.try_mint(address(taxToken), address(god), 20 ether));

        // Joe cannot burn his own tokens.
        assert(!joe.try_burn(address(taxToken), address(joe), 10 ether));

        // Admin cannot burn tokens from the dead wallet.
        assert(!god.try_burn(address(taxToken), address(0), 10 ether));

        // Admin can successfully perform a burn.
        assert(god.try_burn(address(taxToken), address(god), 10 ether));

        // Joe cannot perform an industry burn.
        assert(!joe.try_industryBurn(address(taxToken), address(joe), 10 ether));

        // Admin cannot industry burn from the dead wallet.
        assert(!god.try_industryBurn(address(taxToken), address(0), 10 ether));

        // Admin can successfully perform an industry burn.
        assert(god.try_industryBurn(address(taxToken), address(god), 10 ether));
    }
}
