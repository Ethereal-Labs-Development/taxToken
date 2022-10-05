// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../../lib/ds-test/src/test.sol";
import "./Utility.sol";

// Import sol file.
import "../TaxToken.sol";
import "../Treasury.sol";

// Import interface.
import { IERC20, IUniswapV2Router01, IWETH } from "../interfaces/InterfacesAggregated.sol";

contract MainDeployment_ADMT is Utility {

    // State variable for contract.
    TaxToken taxToken;
    Treasury treasury;

    address UNIV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address UNIV2_PAIR = 0xf1d107ac566473968fC5A90c9EbEFe42eA3248a4;

    event LogUint(string s, uint u);
    event LogArrUint(string s, uint[] u);

    // This setUp() function describes the steps to deploy TaxToken for Andrometa (intended for BSC chain).
    function setUp() public {

        // (1) VERIFY ROUTER IS CORRECT.

        // NOTE: May have to flatten contract upon deployment.

        // (2) Deploy the TaxToken.
        taxToken = new TaxToken(
            100000000000,       // totalSupply()
            'ANDROMETA',        // name()
            'ADMT',             // symbol()
            18,                 // decimals()
            100000000000,       // maxWalletSize()
            100000000000        // maxWalletTx()
        );

        // (3) Deploy the Treasury.
        treasury = new Treasury(
            address(this),
            address(taxToken),
            DAI
        );

        // (4) Update the TaxToken "treasury" state variable.
        taxToken.setTreasury(address(treasury));

        // (5) Update basisPointsTax in TaxToken.
        taxToken.adjustBasisPointsTax(0, 1200);   // 1200 = 12.00 %
        taxToken.adjustBasisPointsTax(1, 1000);   // 1000 = 10.00 %
        taxToken.adjustBasisPointsTax(2, 1200);   // 1200 = 12.00 %

        // (6) Add royalty wallets to whitelist.
        taxToken.modifyWhitelist(0x7f6d45dE87cAB7D2D42bF2709B6b1E2AF994B069, true); // marketing wallet
        taxToken.modifyWhitelist(0xD56acC36Ec1f83d0801493F399b66C2EBBcfba7B, true); // dev wallet
        taxToken.modifyWhitelist(0x7F6c10EE7f1427907f9de6a7e6fd4E0A17DFf442, true); // team wallet
        taxToken.modifyWhitelist(0x6eCF3312f648328B7F846B812fDBb2Ad81630601, true); // angel investor
        taxToken.modifyWhitelist(0x476236c0F13D874b90F33e9CF7947bd6F9C184Cb, true); // staking pool

        // (7) Add address(0), staking contract, owner wallet, and bulkSender to whitelist.
        taxToken.modifyWhitelist(address(0), true);                                 // addy0
        taxToken.modifyWhitelist(0xFebB7A3Ea037eDe59bC78F84f2819C1375d6E685, true); // staking contract - could be different on deployment
        taxToken.modifyWhitelist(address(this), true);                              // whitelist owner wallet
        taxToken.modifyWhitelist(0x458b14915e651243Acf89C05859a22d5Cff976A6, true); // whitelist bulkSender

        // Buy Tax: 10% Total
        //  Marketing: 4%
        //  Dev: 2%
        //  Staking: 2%
        //  Team: 2%

        address[] memory wallets = new address[](4);
        address[] memory convertToAsset = new address[](4);
        uint[] memory percentDistribution = new uint[](4);

        wallets[0] = 0x7f6d45dE87cAB7D2D42bF2709B6b1E2AF994B069; // marketing
        wallets[1] = 0xD56acC36Ec1f83d0801493F399b66C2EBBcfba7B; // dev
        wallets[2] = 0x476236c0F13D874b90F33e9CF7947bd6F9C184Cb; // staking pool
        wallets[3] = 0x7F6c10EE7f1427907f9de6a7e6fd4E0A17DFf442; // team
        convertToAsset[0] = WETH;
        convertToAsset[1] = WETH;
        convertToAsset[2] = WETH;
        convertToAsset[3] = WETH;
        percentDistribution[0] = 40;
        percentDistribution[1] = 20;
        percentDistribution[2] = 20;
        percentDistribution[3] = 20;

        // (8) Update TaxType 0.
        treasury.setTaxDistribution(
            4, 
            wallets, 
            convertToAsset, 
            percentDistribution
        );

        // Sell/xFer Tax: 12% Total
        //  Marketing: 4%
        //  Dev: 2%
        //  Angel: 1%
        //  Staking: 3%
        //  Team: 2%

        wallets = new address[](5);
        convertToAsset = new address[](5);
        percentDistribution = new uint[](5);

        wallets[0] = 0x7f6d45dE87cAB7D2D42bF2709B6b1E2AF994B069; // marketing
        wallets[1] = 0xD56acC36Ec1f83d0801493F399b66C2EBBcfba7B; // dev
        wallets[2] = 0x6eCF3312f648328B7F846B812fDBb2Ad81630601; // angel investor
        wallets[3] = 0x476236c0F13D874b90F33e9CF7947bd6F9C184Cb; // staking pool
        wallets[4] = 0x7F6c10EE7f1427907f9de6a7e6fd4E0A17DFf442; // team
        convertToAsset[0] = WETH;
        convertToAsset[1] = WETH;
        convertToAsset[2] = WETH;
        convertToAsset[3] = WETH;
        convertToAsset[4] = WETH;
        percentDistribution[0] = 33;
        percentDistribution[1] = 17;
        percentDistribution[2] = 8;
        percentDistribution[3] = 25;
        percentDistribution[4] = 17;

        //(9) Update tax types 0 and 2.
        treasury.setTaxDistribution(
            5, 
            wallets, 
            convertToAsset, 
            percentDistribution
        );

        treasury.setTaxDistribution(
            5, 
            wallets, 
            convertToAsset, 
            percentDistribution
        );

        // (10) pause taxToken.
        // NOTE: might have to do between approve and addLiquidity.
        taxToken.pause();
        
        uint ETH_DEPOSIT = 100 ether;
        uint TOKEN_DEPOSIT = 5000000000 ether;

        // (11) Approve TaxToken for UniswapV2Router.
        IERC20(address(taxToken)).approve(
            address(UNIV2_ROUTER), TOKEN_DEPOSIT
        );

        // (12) Instantiate liquidity pool.
        // https://docs.uniswap.org/protocol/V2/reference/smart-contracts/router-02#addliquidityeth
        // NOTE: ETH_DEPOSIT = The amount of ETH to add as liquidity if the token/WETH price is <= amountTokenDesired/msg.value (WETH depreciates).
        IUniswapV2Router01(UNIV2_ROUTER).addLiquidityETH{value: ETH_DEPOSIT}(
            address(taxToken),          // A pool token.
            TOKEN_DEPOSIT,              // The amount of token to add as liquidity if the WETH/token price is <= msg.value/amountTokenDesired (token depreciates).
            5000000000 ether,           // Bounds the extent to which the WETH/token price can go up before the transaction reverts. Must be <= amountTokenDesired.
            100 ether,                  // Bounds the extent to which the token/WETH price can go up before the transaction reverts. Must be <= msg.value.
            address(this),              // Recipient of the liquidity tokens.
            block.timestamp + 300       // Unix timestamp after which the transaction will revert.
        );

        // (14) AIRDROP SNAPSHOT.
        // TODO: VERIFY BULKSENDER IS WHITELISTED
        // NOTE: No need to airdrop private sales again, should be included in snapshot
        // 0x458b14915e651243Acf89C05859a22d5Cff976A6
        // https://bulksender.app/

        // (15) Reduce MaxWalletAmount.
        taxToken.updateMaxWalletSize(400000000);

        // (16) Reduce MaxTxAmount.
        taxToken.updateMaxTxAmount(200000000);

        // (15) Unpause TaxToken.
        taxToken.unpause();

        // (16) Lock LP and remaining tokens.
    }

    // Initial state check.
    function test_andrometa_init_state() public {
        assertEq(taxToken.totalSupply(), 100000000000 ether);
        assertEq(taxToken.name(), 'ANDROMETA');
        assertEq(taxToken.symbol(), 'ADMT');
        assertEq(taxToken.decimals(), 18);
        assertEq(taxToken.maxWalletSize(), 400000000 ether);
        assertEq(taxToken.maxTxAmount(), 200000000 ether);
        assertEq(taxToken.balanceOf(address(this)), taxToken.totalSupply() - 5000000000 ether);
        assertEq(taxToken.treasury(), address(treasury));
    }

    // Test a post deployment buy.
    function test_andrometa_buy() public {
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

        IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path_uni_v2,
            address(32),
            block.timestamp + 300
        );

        emit LogUint("Amount_Recieved_TaxToken", taxToken.balanceOf(address(32)));
    }

    // Test a post deployment sell.
    function test_andrometa_sell() public {
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

        IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path_uni_v2,
            address(32),
            block.timestamp + 300
        );

        emit LogUint("Amount_Received_WETH", IERC20(WETH).balanceOf(address(32)));
    }

    // Test a post deployment buy after pausing the contract.
    function testFail_andrometa_pause_then_buy() public {
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

        IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path_uni_v2,
            address(32),
            block.timestamp + 300
        );
    }

    // Test a post deployment sell atfer pausing the contract.
    function testFail_andrometa_pause_then_sell() public {
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

        IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path_uni_v2,
            address(32),
            block.timestamp + 300
        );
    }

    // Test a post deployment whitelisted buy after pausing the contract.
    function test_andrometa_pause_then_WL_buy() public {
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

        IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path_uni_v2,
            address(32),
            block.timestamp + 300
        );
    }

    // Test a post deployment whitelisted sell after pausing the contract.
    function test_andrometa_pause_then_WL_sell() public {
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

        IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path_uni_v2,
            address(32),
            block.timestamp + 300
        );
    }

}