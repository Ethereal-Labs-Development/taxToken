// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../../lib/ds-test/src/test.sol";
import "./Utility.sol";

// Import sol file.
import "../TaxToken.sol";
import "../Treasury.sol";

// Import interface.
import { IERC20, IUniswapV2Router01, IWETH } from "../interfaces/InterfacesAggregated.sol";

contract MainDeployment_Paradise is Utility {

    // State variable for contract.
    TaxToken taxToken;
    Treasury treasury;

    address UNIV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address UNIV2_PAIR = 0xf1d107ac566473968fC5A90c9EbEFe42eA3248a4;

    event LogUint(string s, uint u);
    event LogArrUint(string s, uint[] u);

    // This setUp() function describes the steps to deploy TaxToken for Paradise (intended for ETH chain).
    function setUp() public {

        // (1) VERIFY ROUTER IS CORRECT.

        // NOTE: May have to flatten contract upon deployment.
        // NOTE: If there is going to be a bulksender airdrop, ensure to whitelist the bulksender
        //       0x458b14915e651243Acf89C05859a22d5Cff976A6

        // (2) Deploy the TaxToken.
        taxToken = new TaxToken(
            88_888_888,         // totalSupply()
            'Paradise',         // name()
            'MOON',             // symbol()
            18,                 // decimals()
            888_888_888,        // maxWalletSize()
            888_888_888         // maxWalletTx()
        );

        // (3) Update maxContractTokenBalance
        taxToken.updateMaxContractTokenBalance(1000);

        // (3) Deploy the Treasury.
        treasury = new Treasury(
            address(this),
            address(taxToken),
            USDC
        );

        // (4) Update the TaxToken "treasury" state variable.
        taxToken.setTreasury(address(treasury));

        // (5) Update basisPointsTax in TaxToken.
        taxToken.adjustBasisPointsTax(0, 1000);   // 1000 = 10.00 %
        taxToken.adjustBasisPointsTax(1, 1000);   // 1000 = 10.00 %
        taxToken.adjustBasisPointsTax(2, 1000);   // 1000 = 10.00 %

        // (6) Add royalty wallets to whitelist.
        taxToken.modifyWhitelist(0xD56acC36Ec1f83d0801493F399b66C2EBBcfba7B, true); // dev wallet
        taxToken.modifyWhitelist(0x7f6d45dE87cAB7D2D42bF2709B6b1E2AF994B069, true); // marketing wallet
        taxToken.modifyWhitelist(0x7F6c10EE7f1427907f9de6a7e6fd4E0A17DFf442, true); // team wallet

        // (7) Add address(0), staking contract, owner wallet, and bulkSender to whitelist.
        taxToken.modifyWhitelist(address(0), true);                                 // addy0
        taxToken.modifyWhitelist(address(this), true);                              // whitelist owner wallet
        taxToken.modifyWhitelist(0x458b14915e651243Acf89C05859a22d5Cff976A6, true); // whitelist bulkSender

        //  Buy Tax: 10% Total
        //  Dev: 1%
        //  Marketing: 4.5%
        //  Team: 4.5%

        address[] memory wallets = new address[](3);
        address[] memory convertToAsset = new address[](3);
        uint[] memory percentDistribution = new uint[](3);

        wallets[0] = 0xD56acC36Ec1f83d0801493F399b66C2EBBcfba7B; // dev
        wallets[1] = 0x7f6d45dE87cAB7D2D42bF2709B6b1E2AF994B069; // marketing
        wallets[2] = 0x7F6c10EE7f1427907f9de6a7e6fd4E0A17DFf442; // team
        convertToAsset[0] = USDC;
        convertToAsset[1] = USDC;
        convertToAsset[2] = USDC;
        percentDistribution[0] = 10;
        percentDistribution[1] = 45;
        percentDistribution[2] = 45;

        // (8) Update TaxType 0.
        treasury.setTaxDistribution(
            3, 
            wallets, 
            convertToAsset, 
            percentDistribution
        );

        // (9) pause taxToken.
        // NOTE: might have to do between approve and addLiquidity.
        taxToken.pause();
        
        uint ETH_DEPOSIT = 35 ether; // roughly $45,000
        uint TOKEN_DEPOSIT = 44_444_444 ether; // calculate amount of tokens for a starting price of $0.01

        // (10) Approve TaxToken for UniswapV2Router.
        IERC20(address(taxToken)).approve(
            address(UNIV2_ROUTER), TOKEN_DEPOSIT
        );

        // (11) Instantiate liquidity pool.
        // https://docs.uniswap.org/protocol/V2/reference/smart-contracts/router-02#addliquidityeth
        // NOTE: ETH_DEPOSIT = The amount of ETH to add as liquidity if the token/WETH price is <= amountTokenDesired/msg.value (WETH depreciates).
        IUniswapV2Router01(UNIV2_ROUTER).addLiquidityETH{value: ETH_DEPOSIT}(
            address(taxToken),          // A pool token.
            TOKEN_DEPOSIT,              // The amount of token to add as liquidity if the WETH/token price is <= msg.value/amountTokenDesired (token depreciates).
            44_444_444 ether,           // Bounds the extent to which the WETH/token price can go up before the transaction reverts. Must be <= amountTokenDesired.
            35 ether,                   // Bounds the extent to which the token/WETH price can go up before the transaction reverts. Must be <= msg.value.
            address(this),              // Recipient of the liquidity tokens.
            block.timestamp + 300       // Unix timestamp after which the transaction will revert.
        );

        // (12) Lock LP and remaining tokens if necessary.

        // (13) Unpause TaxToken -> to go live
        taxToken.unpause();
    }

    // Initial state check.
    function test_paradise_init_state() public {
        assertEq(taxToken.totalSupply(), 88_888_888 ether);
        assertEq(taxToken.name(), 'Paradise');
        assertEq(taxToken.symbol(), 'MOON');
        assertEq(taxToken.decimals(), 18);
        assertEq(taxToken.maxWalletSize(), 888_888_888 ether);
        assertEq(taxToken.maxTxAmount(), 888_888_888 ether);
        assertEq(taxToken.balanceOf(address(this)), taxToken.totalSupply() - 44_444_444 ether);
        assertEq(taxToken.treasury(), address(treasury));
    }

    // Test small buy.
    function test_paradise_small_buy() public {
        uint tradeAmt = 0.001 ether;

        IWETH(WETH).deposit{value: tradeAmt}();
        IERC20(WETH).approve(
            address(UNIV2_ROUTER), tradeAmt
        );

        address[] memory path_uni_v2 = new address[](2);

        path_uni_v2[0] = WETH;
        path_uni_v2[1] = address(taxToken);

        // Get amount of tokens - Quote
        uint[] memory amounts = IUniswapV2Router01(UNIV2_ROUTER).getAmountsOut(
            tradeAmt, 
            path_uni_v2
        );

        // Log array [Amount WETH, amount Paradise token]
        emit LogArrUint('amounts', amounts);
        // Log amount of Paradise Tokens
        emit LogUint('amounts[1]', amounts[1]);

        // Pre-state check.
        assertEq(IERC20(address(taxToken)).balanceOf(address(treasury)), 0);
        assertEq(IERC20(address(WETH)).balanceOf(address(treasury)), 0);
        assertEq(taxToken.balanceOf(address(32)), 0);
        assertEq(taxToken.viewContractTokenBalance(), 0);

        // Perform buy
        IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path_uni_v2,
            address(32),
            block.timestamp + 300
        );

        emit LogUint("Amount_Recieved_TaxToken", taxToken.balanceOf(address(32)));
        emit LogUint("Amount_Taxed", taxToken.viewContractTokenBalance());

        // Post-state check.
        assertEq(amounts[1], taxToken.balanceOf(address(32)) + taxToken.viewContractTokenBalance());
        assertEq(IERC20(address(taxToken)).balanceOf(address(treasury)), 0);
        assertEq(IERC20(address(WETH)).balanceOf(address(treasury)), 0);
        assertGt(taxToken.balanceOf(address(32)), 0);
        assertGt(taxToken.viewContractTokenBalance(), 0);
    }

    // Test big buy.
    function test_paradise_big_buy() public {
        uint tradeAmt = 20 ether;

        IWETH(WETH).deposit{value: tradeAmt}();
        IERC20(WETH).approve(
            address(UNIV2_ROUTER), tradeAmt
        );

        address[] memory path_uni_v2 = new address[](2);

        path_uni_v2[0] = WETH;
        path_uni_v2[1] = address(taxToken);

        // Get amount of tokens - Quote
        uint[] memory amounts = IUniswapV2Router01(UNIV2_ROUTER).getAmountsOut(
            tradeAmt, 
            path_uni_v2
        );

        // Log array [Amount WETH, amount Paradise token]
        emit LogArrUint('amounts', amounts);
        // Log amount of Paradise Tokens
        emit LogUint('amounts[1]', amounts[1]);

        // Pre-state check.
        assertEq(IERC20(address(taxToken)).balanceOf(address(treasury)), 0);
        assertEq(IERC20(address(WETH)).balanceOf(address(treasury)), 0);
        assertEq(taxToken.balanceOf(address(33)), 0);
        assertEq(taxToken.viewContractTokenBalance(), 0);

        // Perform buy
        IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path_uni_v2,
            address(33),
            block.timestamp + 300
        );

        emit LogUint("Amount_Recieved_TaxToken", taxToken.balanceOf(address(33)));
        emit LogUint("Amount_Taxed", taxToken.viewContractTokenBalance());

        // Post-state check.
        assertEq(amounts[1], taxToken.balanceOf(address(33)) + taxToken.viewContractTokenBalance());
        assertEq(IERC20(address(taxToken)).balanceOf(address(treasury)), 0);
        assertEq(IERC20(address(WETH)).balanceOf(address(treasury)), 0);
        assertGt(taxToken.balanceOf(address(33)), 0);
        assertGt(taxToken.viewContractTokenBalance(), 0);
    }

    // Test small sell.
    function test_paradise_small_sell() public {
        uint tradeAmt = 0.001 ether;
        taxToken.transfer(address(32), 0.001 ether);

        emit LogUint("Balance of address 32", taxToken.balanceOf(address(32)));

        taxToken.modifyWhitelist(address(this), false);

        IERC20(address(taxToken)).approve(
            address(UNIV2_ROUTER), tradeAmt
        );

        address[] memory path_uni_v2 = new address[](2);

        path_uni_v2[0] = address(taxToken);
        path_uni_v2[1] = WETH;

        // Get amount of tokens - Quote
        uint[] memory amounts = IUniswapV2Router01(UNIV2_ROUTER).getAmountsOut(
            tradeAmt, 
            path_uni_v2
        );

        // Log array [Amount WETH, amount Paradise token]
        emit LogArrUint('amounts', amounts);
        // Log amount of Paradise Tokens
        emit LogUint('amounts[1]', amounts[1]);

        // Pre-state check.
        assertEq(IERC20(address(taxToken)).balanceOf(address(treasury)), 0);
        assertEq(IERC20(address(WETH)).balanceOf(address(treasury)), 0);
        assertEq(IERC20(WETH).balanceOf(address(32)), 0);
        assertEq(taxToken.viewContractTokenBalance(), 0);

        // Perform buy
        IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path_uni_v2,
            address(32),
            block.timestamp + 300
        );

        emit LogUint("Amount_Received_WETH", IERC20(WETH).balanceOf(address(32)));
        emit LogUint("Amount_Taxed", taxToken.viewContractTokenBalance());

        // Post-state check.
        assertEq(IERC20(address(taxToken)).balanceOf(address(treasury)), 0);
        assertEq(IERC20(address(WETH)).balanceOf(address(treasury)), 0);
        assertGt(IERC20(WETH).balanceOf(address(32)), 0);
        assertGt(taxToken.viewContractTokenBalance(), 0);
    }

    // Test big sell.
    function test_paradise_big_sell() public {
        uint tradeAmt = 22_000_000 ether;
        taxToken.transfer(address(32), 22_000_000 ether);

        emit LogUint("Balance of address 32", taxToken.balanceOf(address(32)));

        taxToken.modifyWhitelist(address(this), false);

        IERC20(address(taxToken)).approve(
            address(UNIV2_ROUTER), tradeAmt
        );

        address[] memory path_uni_v2 = new address[](2);

        path_uni_v2[0] = address(taxToken);
        path_uni_v2[1] = WETH;

        // Get amount of tokens - Quote
        uint[] memory amounts = IUniswapV2Router01(UNIV2_ROUTER).getAmountsOut(
            tradeAmt, 
            path_uni_v2
        );

        // Log array [Amount WETH, amount Paradise token]
        emit LogArrUint('amounts', amounts);
        // Log amount of Paradise Tokens
        emit LogUint('amounts[1]', amounts[1]);

        // Pre-state check.
        assertEq(IERC20(address(taxToken)).balanceOf(address(treasury)), 0);
        assertEq(IERC20(address(WETH)).balanceOf(address(treasury)), 0);
        assertEq(IERC20(WETH).balanceOf(address(32)), 0);
        assertEq(taxToken.viewContractTokenBalance(), 0);

        // Perform buy
        IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path_uni_v2,
            address(32),
            block.timestamp + 300
        );

        emit LogUint("Amount_Received_WETH", IERC20(WETH).balanceOf(address(32)));
        emit LogUint("Amount_Taxed", taxToken.viewContractTokenBalance());

        // Post-state check.
        assertEq(IERC20(address(taxToken)).balanceOf(address(treasury)), 0);
        assertEq(IERC20(address(WETH)).balanceOf(address(treasury)), 0);
        assertGt(IERC20(WETH).balanceOf(address(32)), 0);
        assertGt(taxToken.viewContractTokenBalance(), 0);
    }

    // Test a buy after pausing the contract.
    function testFail_paradise_pause_then_buy() public {
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
        assertEq(IERC20(address(taxToken)).balanceOf(address(32)), 0);

        taxToken.pause(); // pause

        // Execute Buy
        IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path_uni_v2,
            address(32),
            block.timestamp + 300
        );

        assertEq(IERC20(address(taxToken)).balanceOf(address(32)), 0);
    }

    // Test a sell atfer pausing the contract.
    function testFail_paradise_pause_then_sell() public {
        uint tradeAmt = 1 ether;
        taxToken.transfer(address(32), 1 ether);

        emit LogUint("Balance of address 32", taxToken.balanceOf(address(32)));

        taxToken.modifyWhitelist(address(this), false);

        IERC20(address(taxToken)).approve(
            address(UNIV2_ROUTER), tradeAmt
        );

        address[] memory path_uni_v2 = new address[](2);

        path_uni_v2[0] = address(taxToken);
        path_uni_v2[1] = WETH;

        // Pre-state check.
        assertEq(IERC20(address(taxToken)).balanceOf(address(32)), 1 ether);
        assertEq(IERC20(address(WETH)).balanceOf(address(32)), 0);

        taxToken.pause(); // pause

        // Execute Sell
        IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path_uni_v2,
            address(32),
            block.timestamp + 300
        );

        assertEq(IERC20(address(taxToken)).balanceOf(address(32)), 1 ether);
        assertEq(IERC20(address(WETH)).balanceOf(address(32)), 0);
    }

    // Test a whitelisted buy after pausing the contract.
    function test_paradise_pause_then_WL_buy() public {
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
        assertEq(IERC20(address(taxToken)).balanceOf(address(32)), 0);

        // Pause contract
        taxToken.pause();

        // Perform Buy
        IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path_uni_v2,
            address(32),
            block.timestamp + 300
        );

        // Post-state check.
        assertEq(IERC20(address(taxToken)).balanceOf(address(32)), amounts[1]);
    }

    // Test a whitelisted sell after pausing the contract.
    function test_paradise_pause_then_WL_sell() public {
        uint tradeAmt = 1 ether;
        taxToken.transfer(address(32), 1 ether);

        emit LogUint("Balance of address 32", taxToken.balanceOf(address(32)));

        taxToken.modifyWhitelist(address(32), true);

        IERC20(address(taxToken)).approve(
            address(UNIV2_ROUTER), tradeAmt
        );

        address[] memory path_uni_v2 = new address[](2);

        path_uni_v2[0] = address(taxToken);
        path_uni_v2[1] = WETH;

        uint[] memory amounts = IUniswapV2Router01(UNIV2_ROUTER).getAmountsOut(
            tradeAmt, 
            path_uni_v2
        );

        emit LogArrUint('amounts', amounts);
        emit LogUint('amounts[1]', amounts[1]);

        // Pre-state check.
        assertEq(IERC20(address(WETH)).balanceOf(address(32)), 0);
        assertEq(IERC20(address(taxToken)).balanceOf(address(32)), 1 ether);

        // Pause contract
        taxToken.pause();

        // Perform sell
        IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path_uni_v2,
            address(32),
            block.timestamp + 300
        );

        // Post-state check.
        assertEq(IERC20(address(WETH)).balanceOf(address(32)), amounts[1]);
    }

    // Generate multiple buys/sells to generate tax royalties
    function test_paradise_bulk_transactions() public {
        IWETH(WETH).deposit{value: 100 ether}();
        taxToken.modifyWhitelist(address(this), false);


        /// Generate Buy //////////////////////////////////////////////
            uint tradeAmt = 5 ether;

            IERC20(WETH).approve(
                address(UNIV2_ROUTER), tradeAmt
            );

            address[] memory path = new address[](2);

            path[0] = WETH;
            path[1] = address(taxToken);

            IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
                tradeAmt,
                0,
                path,
                address(69),
                block.timestamp + 300
            );

        emit Debug("Contract Token Balance", taxToken.viewContractTokenBalance());
        emit Debug("Treasury WETH Balance", treasury.amountRoyaltiesWeth());


        /// Generate Sell //////////////////////////////////////////////
            tradeAmt = 5 ether;

            IERC20(address(taxToken)).approve(
                address(UNIV2_ROUTER), tradeAmt
            );

            path[0] = address(taxToken);
            path[1] = WETH;

            IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
                tradeAmt,           
                0,
                path,
                address(69),
                block.timestamp + 300
            );

        emit Debug("Contract Token Balance", taxToken.viewContractTokenBalance());
        emit Debug("Treasury WETH Balance", treasury.amountRoyaltiesWeth());


        /// Generate Sell /////////////////////////////////////////////////
            tradeAmt = 5 ether;

            IERC20(address(taxToken)).approve(
                address(UNIV2_ROUTER), tradeAmt
            );

            path[0] = address(taxToken);
            path[1] = WETH;

            IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
                tradeAmt,           
                0,
                path,
                address(69),
                block.timestamp + 300
            );

        emit Debug("Contract Token Balance", taxToken.viewContractTokenBalance());
        emit Debug("Treasury WETH Balance", treasury.amountRoyaltiesWeth());

        // post-check.
    }
}