// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../../lib/ds-test/src/test.sol";
import "./Utility.sol";

// Import sol file
import "../TaxToken.sol";
import "../Treasury.sol";

// Import interface.
import { IERC20, IUniswapV2Router01, IWETH } from "../interfaces/InterfacesAggregated.sol";

contract MainDeployment_RX2 is Utility {

    // State variable for contract.
    TaxToken taxToken;
    Treasury treasury;

    address UNIV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address UNIV2_PAIR = 0xf1d107ac566473968fC5A90c9EbEFe42eA3248a4;

    event LogUint(string s, uint u);
    event LogArrUint(string s, uint[] u);

    // This setUp() function describes the steps to deploy TaxToken for Royal Riches (RX2) in live.
    function setUp() public {

        // (1) Deploy the TaxToken.
        taxToken = new TaxToken(
            300000000,          // Initial liquidity (300mm)
            'Royal Riches',     // Name of token.
            'RX2',              // Symbol of token.
            18,                 // Precision of decimals.
            10000000,           // Max wallet (10mm)
            300000000           // Max transaction (300mm)
        );

        // (2) Deploy the Treasury.
        treasury = new Treasury(
            address(this),
            address(taxToken)
        );

        // (3) Update the TaxToken "treasury" state variable.
        taxToken.setTreasury(address(treasury));

        // (4, 5, 6) Update basisPointsTax in TaxToken.
        taxToken.adjustBasisPointsTax(0, 1500);   // 1500 = 15.00 %
        taxToken.adjustBasisPointsTax(1, 1500);   // 1500 = 15.00 %
        taxToken.adjustBasisPointsTax(2, 1500);   // 1500 = 15.00 %

        // (7, 8, 9, 10, 11) Add wallets to whitelist.
        taxToken.modifyWhitelist(0xD964a3866BCc967E55768db65a47C9069AD2f2a4, true);
        taxToken.modifyWhitelist(0x608Af7d60d8E9C6C60E336A27AaA4810D644455e, true);
        taxToken.modifyWhitelist(0xf3e9dC29cA7487DFE7924cAf7A48755cf6752438, true);
        taxToken.modifyWhitelist(0x4B5fa78b52b3488cB3326e7188dfDf315fD0D392, true);
        taxToken.modifyWhitelist(address(0), true);

        // (12, 13) Add Treasury, Admin to whitelist.
        taxToken.modifyWhitelist(address(treasury), true);
        taxToken.modifyWhitelist(address(this), true);

        // Marketing (5%)   = 0xD964a3866BCc967E55768db65a47C9069AD2f2a4
        // Buyback (5%)     = 0x608Af7d60d8E9C6C60E336A27AaA4810D644455e
        // Dev (3%)         = 0xf3e9dC29cA7487DFE7924cAf7A48755cf6752438
        // Use (2%)         = 0x4B5fa78b52b3488cB3326e7188dfDf315fD0D392
        address[] memory wallets = new address[](4);
        address[] memory convertToAsset = new address[](4);
        uint[] memory percentDistribution = new uint[](4);

        wallets[0] = 0xD964a3866BCc967E55768db65a47C9069AD2f2a4;
        wallets[1] = 0x608Af7d60d8E9C6C60E336A27AaA4810D644455e;
        wallets[2] = 0xf3e9dC29cA7487DFE7924cAf7A48755cf6752438;
        wallets[3] = 0x4B5fa78b52b3488cB3326e7188dfDf315fD0D392;
        convertToAsset[0] = WETH;
        convertToAsset[1] = WETH;
        convertToAsset[2] = WETH;
        convertToAsset[3] = WETH;
        percentDistribution[0] = 33;
        percentDistribution[1] = 33;
        percentDistribution[2] = 21;
        percentDistribution[3] = 13;

        // (14, 15, 16) Update TaxType 0, 1, 2.
        treasury.setTaxDistribution(
            0, 
            4, 
            wallets, 
            convertToAsset, 
            percentDistribution
        );

        treasury.setTaxDistribution(
            1, 
            4, 
            wallets, 
            convertToAsset, 
            percentDistribution
        );

        treasury.setTaxDistribution(
            2, 
            4, 
            wallets, 
            convertToAsset, 
            percentDistribution
        );
        
        uint ETH_DEPOSIT = 16.66 ether;
        uint TOKEN_DEPOSIT = 100000000 ether;

        // (18) Approve TaxToken for UniswapV2Router.
        IERC20(address(taxToken)).approve(
            address(UNIV2_ROUTER), TOKEN_DEPOSIT
        );

        // (19) Pause TaxToken.
        taxToken.pause();

        // (20) Instantiate liquidity pool.
        // https://docs.uniswap.org/protocol/V2/reference/smart-contracts/router-02#addliquidityeth
        // NOTE: ETH_DEPOSIT = The amount of ETH to add as liquidity if the token/WETH price is <= amountTokenDesired/msg.value (WETH depreciates).
        IUniswapV2Router01(UNIV2_ROUTER).addLiquidityETH{value: ETH_DEPOSIT}(
            address(taxToken),          // A pool token.
            TOKEN_DEPOSIT,                // The amount of token to add as liquidity if the WETH/token price is <= msg.value/amountTokenDesired (token depreciates).
            100000000 ether,            // Bounds the extent to which the WETH/token price can go up before the transaction reverts. Must be <= amountTokenDesired.
            16.66 ether,                // Bounds the extent to which the token/WETH price can go up before the transaction reverts. Must be <= msg.value.
            address(this),              // Recipient of the liquidity tokens.
            block.timestamp + 300       // Unix timestamp after which the transaction will revert.
        );

        // (21) Reduce MaxTxAmount post-liquidity-pool-deposit to (6mm).
        taxToken.updateMaxTxAmount(6000000);

        // (22) Unpause TaxToken.
        taxToken.unpause();

    }

    // Initial state check.
    function test_royal_riches_init_state() public {
        assertEq(300000000 ether, taxToken.totalSupply());
        assertEq('Royal Riches', taxToken.name());
        assertEq('RX2', taxToken.symbol());
        assertEq(18, taxToken.decimals());
        assertEq(10000000 ether, taxToken.maxWalletSize());
        assertEq(6000000 ether, taxToken.maxTxAmount());
        assertEq(taxToken.balanceOf(address(this)), taxToken.totalSupply() - 100000000 ether);
        assertEq(taxToken.treasury(), address(treasury));
    }

    // Test a post deployment buy
    function test_royal_riches_buy() public {
        uint tradeAmt = 1 ether;

        IWETH(WETH).deposit{value: tradeAmt}();
        IERC20(WETH).approve(
            address(UNIV2_ROUTER), tradeAmt
        );

        address[] memory path_uni_v2 = new address[](2);

        path_uni_v2[0] = WETH;
        path_uni_v2[1] = address(taxToken);

        uint[] memory amounts = IUniswapV2Router01(UNIV2_ROUTER).getAmountsOut(
            tradeAmt, 
            path_uni_v2
        );

        emit LogArrUint('amounts', amounts);
        emit LogUint('amounts[1]', amounts[1]);

        // Pre-state check.
        assertEq(IERC20(address(taxToken)).balanceOf(address(treasury)), 0);

        IUniswapV2Router01(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path_uni_v2,
            address(32),
            block.timestamp + 300
        );

        emit LogUint("Amount_Recieved_TaxToken", taxToken.balanceOf(address(32)));
    }

    // Test a post deployment sell
    function test_royal_riches_sell() public {
        uint tradeAmt = 1 ether;
        taxToken.transfer(address(32), 2 ether);

        emit LogUint("Balance of address 32", taxToken.balanceOf(address(32)));

        taxToken.modifyWhitelist(address(this), false); // Had to remove address(this) from whitelist to yield a taxed sell

        IERC20(address(taxToken)).approve(
            address(UNIV2_ROUTER), tradeAmt
        );

        address[] memory path_uni_v2 = new address[](2);

        path_uni_v2[0] = address(taxToken);
        path_uni_v2[1] = WETH;

        IUniswapV2Router01(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path_uni_v2,
            address(32),
            block.timestamp + 300
        );

        emit LogUint("Amount_Received_WETH", IERC20(WETH).balanceOf(address(32)));
    }

    // Test a post deployment buy after pausing the contract
    function testFail_royal_riches_pause_then_buy() public {
        uint tradeAmt = 1 ether;

        IERC20(WETH).approve(
            address(UNIV2_ROUTER), tradeAmt
        );

        address[] memory path_uni_v2 = new address[](2);

        path_uni_v2[0] = WETH;
        path_uni_v2[1] = address(taxToken);

        uint[] memory amounts = IUniswapV2Router01(UNIV2_ROUTER).getAmountsOut(
            tradeAmt, 
            path_uni_v2
        );

        emit LogArrUint('amounts', amounts);
        emit LogUint('amounts[1]', amounts[1]);

        // Pre-state check.
        assertEq(IERC20(address(taxToken)).balanceOf(address(treasury)), 0);

        taxToken.pause(); // pause

        IUniswapV2Router01(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path_uni_v2,
            address(32),
            block.timestamp + 300
        );
    }

    // Test a post deployment sell atfer pausing the contract
    function testFail_royal_riches_pause_then_sell() public {
        uint tradeAmt = 1 ether;
        taxToken.transfer(address(32), 2 ether);

        emit LogUint("Balance of address 32", taxToken.balanceOf(address(32)));

        taxToken.modifyWhitelist(address(this), false);

        IERC20(address(taxToken)).approve(
            address(UNIV2_ROUTER), tradeAmt
        );

        address[] memory path_uni_v2 = new address[](2);

        path_uni_v2[0] = address(taxToken);
        path_uni_v2[1] = WETH;

        taxToken.pause(); // pause

        IUniswapV2Router01(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path_uni_v2,
            address(32),
            block.timestamp + 300
        );
    }

    // Test a post deployment whitelisted buy after pausing the contract
    function test_royal_riches_pause_then_WL_buy() public {
        uint tradeAmt = 1 ether;
        
        taxToken.modifyWhitelist(address(32), true);

        IWETH(WETH).deposit{value: tradeAmt}();
        IERC20(WETH).approve(
            address(UNIV2_ROUTER), tradeAmt
        );

        address[] memory path_uni_v2 = new address[](2);

        path_uni_v2[0] = WETH;
        path_uni_v2[1] = address(taxToken);

        uint[] memory amounts = IUniswapV2Router01(UNIV2_ROUTER).getAmountsOut(
            tradeAmt, 
            path_uni_v2
        );

        emit LogArrUint('amounts', amounts);
        emit LogUint('amounts[1]', amounts[1]);

        // Pre-state check.
        assertEq(IERC20(address(taxToken)).balanceOf(address(treasury)), 0);

        taxToken.pause();

        IUniswapV2Router01(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path_uni_v2,
            address(32),
            block.timestamp + 300
        );
    }

    // Test a post deployment whitelisted sell after pausing the contract
    function test_royal_riches_pause_then_WL_sell() public {
        uint tradeAmt = 1 ether;
        taxToken.transfer(address(32), 2 ether);

        emit LogUint("Balance of address 32", taxToken.balanceOf(address(32)));

        taxToken.modifyWhitelist(address(32), true);

        IERC20(address(taxToken)).approve(
            address(UNIV2_ROUTER), tradeAmt
        );

        address[] memory path_uni_v2 = new address[](2);

        path_uni_v2[0] = address(taxToken);
        path_uni_v2[1] = WETH;

        taxToken.pause();

        IUniswapV2Router01(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path_uni_v2,
            address(32),
            block.timestamp + 300
        );
    }

}