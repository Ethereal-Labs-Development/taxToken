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

        // (2) Deploy the TaxToken.
        taxToken = new TaxToken(
            88_888_888,         // totalSupply()
            'Paradise',         // name()
            'PDC',              // symbol()
            18,                 // decimals()
            888_888,            // maxWalletSize()
            888_888             // maxWalletTx()
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
        convertToAsset[0] = WETH;
        convertToAsset[1] = WETH;
        convertToAsset[2] = WETH;
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

        //  Sell/Xfer Tax: 10% Total
        //  Dev: 1%
        //  Marketing: 4.5%
        //  Team: 4.5%

        wallets = new address[](3);
        convertToAsset = new address[](3);
        percentDistribution = new uint[](3);

        wallets[0] = 0xD56acC36Ec1f83d0801493F399b66C2EBBcfba7B; // dev
        wallets[1] = 0x7f6d45dE87cAB7D2D42bF2709B6b1E2AF994B069; // marketing
        wallets[2] = 0x7F6c10EE7f1427907f9de6a7e6fd4E0A17DFf442; // team
        convertToAsset[0] = WETH;
        convertToAsset[1] = WETH;
        convertToAsset[2] = WETH;
        percentDistribution[0] = 10;
        percentDistribution[1] = 45;
        percentDistribution[2] = 45;

        //(9) Update tax types 0 and 2.
        treasury.setTaxDistribution(
            3, 
            wallets, 
            convertToAsset, 
            percentDistribution
        );

        treasury.setTaxDistribution(
            3, 
            wallets, 
            convertToAsset, 
            percentDistribution
        );

        // (10) pause taxToken.
        // NOTE: might have to do between approve and addLiquidity.
        taxToken.pause();
        
        uint ETH_DEPOSIT = 45 ether;
        uint TOKEN_DEPOSIT = 44_444_444 ether;

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
            44_444_444 ether,           // Bounds the extent to which the WETH/token price can go up before the transaction reverts. Must be <= amountTokenDesired.
            45 ether,                  // Bounds the extent to which the token/WETH price can go up before the transaction reverts. Must be <= msg.value.
            address(this),              // Recipient of the liquidity tokens.
            block.timestamp + 300       // Unix timestamp after which the transaction will revert.
        );

        // (14) AIRDROP SNAPSHOT.
        // TODO: VERIFY BULKSENDER IS WHITELISTED
        // NOTE: No need to airdrop private sales again, should be included in snapshot
        // 0x458b14915e651243Acf89C05859a22d5Cff976A6
        // https://bulksender.app/

        // (15) Reduce MaxWalletAmount.
        taxToken.updateMaxWalletSize(444_444);  // 1% of the LP

        // (16) Reduce MaxTxAmount.
        taxToken.updateMaxTxAmount(444_444);    // 1% of the LP

        // (15) Unpause TaxToken.
        taxToken.unpause();

        // (16) Lock LP and remaining tokens.
    }