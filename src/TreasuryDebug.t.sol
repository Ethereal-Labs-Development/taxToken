// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../lib/ds-test/src/test.sol";

import "./Utility/Utility.sol";

import "./TaxToken.sol";
import "./Treasury.sol";

import { IERC20, IUniswapV2Router01, IWETH } from "./interfaces/ERC20.sol";


contract TreasuryNullTest is Utility {

    TaxToken taxToken;
    Treasury treasury;

    address UNIV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    function setUp() public {

        createActors();

        taxToken = new TaxToken(
            100000000000,           // totalSupply
            'ANDROMETA',            // name
            'ADMT',                 // symbol
            18,                     // decimals
            100000000000,              // maxWalletSize (* 10**18) - 150000000
            100000000000             // maxTxAmount (* 10**18) - 10000000000
        );

        taxToken.transferOwnership(address(admin));

        treasury = new Treasury(
            address(admin), address(taxToken), 2000000
        );

        assert(admin.try_setTreasury(address(taxToken), address(treasury)));

        // Set basisPointsTax for taxType 0 / 1 / 2
        // taxType 0 => Xfer Tax (10%)  => 10% (1wallets, marketing)
        // taxType 1 => Buy Tax (12%)   => 6%/6% (2wallets, use/marketing))
        // taxType 2 => Sell Tax (15%)  => 5%/4%/6% (3wallets, use/marketing/staking)
        taxToken.adjustBasisPointsTax(0, 1000);   // 1000 = 10.00 %
        taxToken.adjustBasisPointsTax(1, 1200);   // 1200 = 12.00 %
        taxToken.adjustBasisPointsTax(2, 1500);   // 1500 = 15.00 %

        // Setup Treasury.sol, initialize liquidity pool.
        treasury_setDistribution();
        create_lp();

        // taxToken.updateMaxWalletSize(150000000);
        // taxToken.updateMaxTxAmount(10000000000);

        taxToken.modifyWhitelist(address(this), false);

        // Simulate trades.
        buy_generateFees();
        sell_generateFees();
        xfer_generateFees();

        taxToken.modifyWhitelist(address(this), true);
    }


    // -----------------
    // Utility Functions
    // -----------------

    function buy_generateFees() public {

        // Simulate buy (taxType 1)

        uint tradeAmt = 1 ether;

        IERC20(WETH).approve(
            address(UNIV2_ROUTER), tradeAmt
        );

        address[] memory path_uni_v2 = new address[](2);

        path_uni_v2[0] = WETH;
        path_uni_v2[1] = address(taxToken);

        emit Debug('preBalTaxToken', taxToken.balanceOf(address(this)));
        uint preBalTaxtoken = taxToken.balanceOf(address(this));
        IUniswapV2Router01(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path_uni_v2,
            address(this),
            block.timestamp + 300
        );
        uint postBalTaxToken = taxToken.balanceOf(address(this));
        emit Debug('postBalTaxToken', taxToken.balanceOf(address(this)));
        emit Debug('diff', postBalTaxToken - preBalTaxtoken);
    }

    function sell_generateFees() public {
        // Simulate sell (taxType 2)

        uint tradeAmt = 100000000 ether;

        IERC20(address(taxToken)).approve(
            address(UNIV2_ROUTER), tradeAmt
        );

        address[] memory path_uni_v2 = new address[](2);

        path_uni_v2[0] = address(taxToken);
        path_uni_v2[1] = WETH;

        // Documentation on IUniswapV2Router:
        // https://docs.uniswap.org/protocol/V2/reference/smart-contracts/router-02#swapexacttokensfortokens
        IUniswapV2Router01(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,           
            0,
            path_uni_v2,
            msg.sender,
            block.timestamp + 300
        );
    }

    function xfer_generateFees() public {
        // Simulate xfer (taxType 0)
        taxToken.transfer(address(0), 200000000 ether);
    }

    function treasury_setDistribution() public {
        address[] memory wallets = new address[](4);
        address[] memory convertToAsset = new address[](4);
        uint[] memory percentDistribution = new uint[](4);

        wallets[0] = address(11);
        wallets[1] = address(12);
        wallets[2] = address(13);
        wallets[3] = address(14);
        convertToAsset[0] = WETH;
        convertToAsset[1] = WETH;
        convertToAsset[2] = WETH;
        convertToAsset[3] = WETH;
        percentDistribution[0] = 40;
        percentDistribution[1] = 30;
        percentDistribution[2] = 20;
        percentDistribution[3] = 10;

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
    }

    function create_lp() public {
        // Convert our ETH to WETH
        uint TAX_DEPOSIT = 5000000000 ether;
        uint ETH_DEPOSIT = 100 ether;

        IWETH(WETH).deposit{value: ETH_DEPOSIT}();

        IERC20(WETH).approve(
            address(UNIV2_ROUTER), ETH_DEPOSIT
        );
        IERC20(address(taxToken)).approve(
            address(UNIV2_ROUTER), TAX_DEPOSIT
        );

        taxToken.modifyWhitelist(address(this), true);

        // Instantiate liquidity pool.
        // TODO: Research params for addLiquidityETH (which one is for TaxToken amount?).
        IUniswapV2Router01(UNIV2_ROUTER).addLiquidityETH{value: ETH_DEPOSIT}(
            address(taxToken),
            TAX_DEPOSIT,            // This variable is the TaxToken amount to deposit.
            TAX_DEPOSIT,
            100 ether,
            address(this),
            block.timestamp + 300
        );
    }

    
    // ----------
    // Test Cases
    // ----------

    function test_treasuryDebug_init_state() public {
        // Log treasury holdings.
        (uint _taxType0, uint _taxType1, uint _taxType2, uint _sum) = treasury.viewTaxesAccrued();
        emit Debug('_taxType0', _taxType0);
        emit Debug('_taxType1', _taxType1);
        emit Debug('_taxType2', _taxType2);
        emit Debug('_sum', _sum);

        emit Debug('is_owner_WL', taxToken.whitelist(address(this)));
        emit Debug('is_bulkSender_WL', taxToken.whitelist(taxToken.bulkSender()));
        emit Debug('is_address(0)_WL', taxToken.whitelist(address(0)));

        emit Debug('threshold', treasury.taxDistributionThreshold());
    }

    // Ensure wallet cannot be added to blacklist if already in whitelist
    function testFail_treasuryDebug_blackListFail() public {
        taxToken.modifyWhitelist(address(69), true);
        taxToken.modifyBlacklist(address(69), true);
    }

    // Ensure we cannot blacklist treasury
    function testFail_treasuryDebug_blacklistTreasury() public {
        taxToken.modifyBlacklist(address(treasury), true);
    }
}