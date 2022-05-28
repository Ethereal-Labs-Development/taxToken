// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../lib/ds-test/src/test.sol";
import "./Utility.sol";

// Import sol file
import "./TaxToken.sol";
import "./Treasury.sol";

// Import interface.
import { IERC20, IUniswapV2Router01, IWETH } from "./interfaces/ERC20.sol";

contract TreasuryTest is Utility {

    // State variable for contract.
    TaxToken taxToken;
    Treasury treasury;

    address UNIV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address UNIV2_PAIR = 0xf1d107ac566473968fC5A90c9EbEFe42eA3248a4;

    event LogUint(string s, uint u);
    event LogArrUint(string s, uint[] u);

    // Deploy token, specify input params.
    // setUp() runs before every tests conduct.
    function setUp() public {

        // Token instantiation.
        taxToken = new TaxToken(
            1000000000,                // Initial liquidity
            'ProveZero',               // Name of token.
            'PROZ',                    // Symbol of token.
            18,                        // Precision of decimals.
            1000000,                   // Max wallet size
            100000                     // Max transaction amount
        );

        treasury = new Treasury(
            address(this), address(taxToken), 1000
        );

        taxToken.setTreasury(address(treasury));


        // Set basisPointsTax for taxType 0 / 1 / 2
        // taxType 0 => Xfer Tax (10%)  => 10% (1wallets, marketing)
        // taxType 1 => Buy Tax (12%)   => 6%/6% (2wallets, use/marketing))
        // taxType 2 => Sell Tax (15%)  => 5%/4%/6% (3wallets, use/marketing/staking)
        taxToken.adjustBasisPointsTax(0, 1000);   // 1000 = 10.00 %
        taxToken.adjustBasisPointsTax(1, 1200);   // 1200 = 12.00 %
        taxToken.adjustBasisPointsTax(2, 1500);   // 1500 = 15.00 %

        taxToken.modifyWhitelist(address(treasury), true);

        
        // Convert our ETH to WETH
        uint ETH_DEPOSIT = 100 ether;
        uint TAX_DEPOSIT = 10000 ether;

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
            10 ether,
            10 ether,
            address(this),
            block.timestamp + 300
        );

        taxToken.modifyWhitelist(address(this), false);

        buy_generateFees();
        sell_generateFees();
        xfer_generateFees();

    }

    function buy_generateFees() public {

        // Simulate buy (taxType 1)

        uint tradeAmt = 10 ether;

        IERC20(WETH).approve(
            address(UNIV2_ROUTER), tradeAmt
        );

        address[] memory path_uni_v2 = new address[](2);

        path_uni_v2[0] = WETH;
        path_uni_v2[1] = address(taxToken);

        IUniswapV2Router01(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path_uni_v2,
            msg.sender,
            block.timestamp + 300
        );
    }

    function sell_generateFees() public {
        // Simulate sell (taxType 2)

        uint tradeAmt = 10 ether;

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
        taxToken.transfer(address(69), 1 ether);
    }



    // Initial state check on treasury.
    // Each taxType (0, 1, and 2) should have some greater than 0 value.
    // The sum of all taxes accrued for each taxType should equal taxToken.balanceOf(treasury).
    function test_treasury_initialState() public {
        assert(treasury.taxTokenAccruedForTaxType(0) > 0);
        assert(treasury.taxTokenAccruedForTaxType(1) > 0);
        assert(treasury.taxTokenAccruedForTaxType(2) > 0);
        uint sum = treasury.taxTokenAccruedForTaxType(0) + treasury.taxTokenAccruedForTaxType(1) + treasury.taxTokenAccruedForTaxType(2);
        assertEq(sum, taxToken.balanceOf(address(treasury)));
    }

    // Test require statement fail: require(walletCount == wallets.length)
    function testFail_treasury_modify_taxSetting_require_0() public {
        address[] memory wallets = new address[](3);
        address[] memory convertToAsset = new address[](2);
        uint[] memory percentDistribution = new uint[](2);
        
        wallets[0] = address(0);
        wallets[1] = address(1);
        wallets[2] = address(2);
        convertToAsset[0] = address(taxToken);
        convertToAsset[1] = address(taxToken);
        percentDistribution[0] = 50;
        percentDistribution[1] = 50;
        
        treasury.setTaxDistribution(
            0, 
            2, 
            wallets, 
            convertToAsset, 
            percentDistribution
        );
    }

    // Test require statement fail: require(walletCount == convertToAsset.length)
    function testFail_treasury_modify_taxSetting_require_1() public {
        address[] memory wallets = new address[](2);
        address[] memory convertToAsset = new address[](3);
        uint[] memory percentDistribution = new uint[](2);
        
        wallets[0] = address(0);
        wallets[1] = address(1);
        convertToAsset[0] = address(taxToken);
        convertToAsset[1] = address(taxToken);
        convertToAsset[2] = address(taxToken);
        percentDistribution[0] = 50;
        percentDistribution[1] = 50;
        
        treasury.setTaxDistribution(
            0, 
            2, 
            wallets, 
            convertToAsset, 
            percentDistribution
        );
    }

    // Test require statement fail: require(walletCount == percentDistribution.length)
    function testFail_treasury_modify_taxSetting_require_2() public {
        address[] memory wallets = new address[](2);
        address[] memory convertToAsset = new address[](2);
        uint[] memory percentDistribution = new uint[](3);
        
        wallets[0] = address(0);
        wallets[1] = address(1);
        convertToAsset[0] = address(taxToken);
        convertToAsset[1] = address(taxToken);
        percentDistribution[0] = 50;
        percentDistribution[1] = 49;
        percentDistribution[2] = 1;
        
        treasury.setTaxDistribution(
            0, 
            2, 
            wallets, 
            convertToAsset, 
            percentDistribution
        );
    }

    // Test require statement fail: require(sumPercentDistribution == 100)
    function testFail_treasury_modify_taxSetting_require_3() public {
        address[] memory wallets = new address[](2);
        address[] memory convertToAsset = new address[](2);
        uint[] memory percentDistribution = new uint[](2);
        
        wallets[0] = address(0);
        wallets[1] = address(1);
        convertToAsset[0] = address(taxToken);
        convertToAsset[1] = address(taxToken);
        percentDistribution[0] = 50;
        percentDistribution[1] = 49;
        
        treasury.setTaxDistribution(
            0, 
            2, 
            wallets, 
            convertToAsset, 
            percentDistribution
        );
    }

    // Test that modifying taxSetting works (or initialization).
    // Perform initialization, then perform modification (two function calls).
    function test_treasury_modify_taxSetting() public {
        address[] memory wallets = new address[](2);
        address[] memory convertToAsset = new address[](2);
        uint[] memory percentDistribution = new uint[](2);
        
        wallets[0] = address(0);
        wallets[1] = address(1);
        convertToAsset[0] = address(taxToken);
        convertToAsset[1] = address(taxToken);
        percentDistribution[0] = 50;
        percentDistribution[1] = 50;
        
        treasury.setTaxDistribution(
            0, 
            2, 
            wallets, 
            convertToAsset, 
            percentDistribution
        );

        (
            uint256 _walletCount, 
            address[] memory _wallets, 
            address[] memory _convertToAsset, 
            uint[] memory _percentDistribution
        ) = treasury.viewTaxSettings(0);

        assertEq(_walletCount, 2);
        assertEq(_wallets[0], address(0));
        assertEq(_wallets[1], address(1));
        assertEq(_convertToAsset[0], address(taxToken));
        assertEq(_convertToAsset[1], address(taxToken));
        assertEq(_percentDistribution[0], 50);
        assertEq(_percentDistribution[1], 50);

        wallets = new address[](3);
        convertToAsset = new address[](3);
        percentDistribution = new uint[](3);
        
        wallets[0] = address(5);
        wallets[1] = address(6);
        wallets[2] = address(7);
        convertToAsset[0] = address(9);
        convertToAsset[1] = address(10);
        convertToAsset[2] = address(10);
        percentDistribution[0] = 30;
        percentDistribution[1] = 30;
        percentDistribution[2] = 40;
        
        treasury.setTaxDistribution(
            0, 
            3, 
            wallets, 
            convertToAsset, 
            percentDistribution
        );

        (
            _walletCount, 
            _wallets, 
            _convertToAsset, 
             _percentDistribution
        ) = treasury.viewTaxSettings(0);

        assertEq(_walletCount, 3);
        assertEq(_wallets[0], address(5));
        assertEq(_wallets[1], address(6));
        assertEq(_wallets[2], address(7));
        assertEq(_convertToAsset[0], address(9));
        assertEq(_convertToAsset[1], address(10));
        assertEq(_convertToAsset[2], address(10));
        assertEq(_percentDistribution[0], 30);
        assertEq(_percentDistribution[1], 30);
        assertEq(_percentDistribution[2], 40);
    }

    function test_treasury_taxDistribution() public {

        address[] memory wallets = new address[](2);
        address[] memory convertToAsset = new address[](2);
        uint[] memory percentDistribution = new uint[](2);
        
        wallets[0] = address(0);
        wallets[1] = address(1);
        convertToAsset[0] = address(taxToken);
        convertToAsset[1] = address(taxToken);
        percentDistribution[0] = 50;
        percentDistribution[1] = 50;

        treasury.setTaxDistribution(
            1, 
            2, 
            wallets, 
            convertToAsset, 
            percentDistribution
        );

        uint _preTaxAccrued = treasury.taxTokenAccruedForTaxType(1);

        assertEq(treasury.distributeTaxes(1), _preTaxAccrued);
    }

    function test_treasury_taxDistribution_conversion() public {

        address[] memory wallets = new address[](2);
        address[] memory convertToAsset = new address[](2);
        uint[] memory percentDistribution = new uint[](2);
        
        wallets[0] = address(0);
        wallets[1] = address(1);
        convertToAsset[0] = address(taxToken);
        convertToAsset[1] = WETH;
        percentDistribution[0] = 50;
        percentDistribution[1] = 50;
        
        treasury.setTaxDistribution(
            1, 
            2, 
            wallets, 
            convertToAsset, 
            percentDistribution
        );

        uint _preTaxAccrued = treasury.taxTokenAccruedForTaxType(1);
        
        assertEq(treasury.distributeTaxes(1), _preTaxAccrued);
    }


    // This test covers multiple tax generation events (of type 0, 1, 2) and collections.
    function test_treasury_multiple_gens_collections() public {
        treasury.distributeAllTaxes();
        buy_generateFees();
        treasury.distributeAllTaxes();
        sell_generateFees();
        treasury.distributeAllTaxes();
        xfer_generateFees();
        treasury.distributeAllTaxes();
        sell_generateFees();
        buy_generateFees();
        treasury.distributeAllTaxes();
        sell_generateFees();
        xfer_generateFees();
        treasury.distributeAllTaxes();
        buy_generateFees();
        xfer_generateFees();
        treasury.distributeAllTaxes();
        sell_generateFees();
        buy_generateFees();
        xfer_generateFees();
        treasury.distributeAllTaxes();
    }
    
    function test_view_function_taxesAccrued() public {
        (
            uint _taxType0,
            uint _taxType1,
            uint _taxType2,
            uint _sum
        ) = treasury.viewTaxesAccrued();

        emit LogUint("_taxType0", _taxType0);
        emit LogUint("_taxType1", _taxType1);
        emit LogUint("_taxType2", _taxType2);
        emit LogUint("_sum", _sum);
        assert(_taxType0 > 0);
        assert(_taxType1 > 0);
        assert(_taxType2 > 0);
        assertEq(_sum, taxToken.balanceOf(address(treasury)));
    }

    function test_treasury_safeWithdraw_USDC() public {
        
        // Buy USDC through Uniswap and deposit into Treasury.
        uint tradeAmt = 10 ether;

        IERC20(WETH).approve(
            address(UNIV2_ROUTER), tradeAmt
        );

        address[] memory path_uni_v2 = new address[](2);

        path_uni_v2[0] = WETH;
        path_uni_v2[1] = address(USDC);

        IUniswapV2Router01(UNIV2_ROUTER).swapExactTokensForTokens(
            tradeAmt,
            0,
            path_uni_v2,
            address(treasury),  // Send USDC to treasury instead of msg.sender
            block.timestamp + 300
        );

        uint preBal_treasury = IERC20(USDC).balanceOf(address(treasury));
        uint preBal_admin = IERC20(USDC).balanceOf(address(this));

        treasury.safeWithdraw(USDC);

        uint postBal_treasury = IERC20(USDC).balanceOf(address(treasury));
        uint postBal_admin = IERC20(USDC).balanceOf(address(this));

        assertEq(preBal_admin, postBal_treasury);
        assertEq(postBal_admin, preBal_treasury);
    }

    function test_treasury_safeWithdraw_DAI() public {
        
        // Buy DAI through Uniswap and deposit into Treasury.
        uint tradeAmt = 10 ether;

        IERC20(WETH).approve(
            address(UNIV2_ROUTER), tradeAmt
        );

        address[] memory path_uni_v2 = new address[](2);

        path_uni_v2[0] = WETH;
        path_uni_v2[1] = address(DAI);

        IUniswapV2Router01(UNIV2_ROUTER).swapExactTokensForTokens(
            tradeAmt,
            0,
            path_uni_v2,
            address(treasury),  // Send DAI to treasury instead of msg.sender
            block.timestamp + 300
        );

        uint preBal_treasury = IERC20(DAI).balanceOf(address(treasury));
        uint preBal_admin = IERC20(DAI).balanceOf(address(this));

        treasury.safeWithdraw(DAI);

        uint postBal_treasury = IERC20(DAI).balanceOf(address(treasury));
        uint postBal_admin = IERC20(DAI).balanceOf(address(this));

        assertEq(preBal_admin, postBal_treasury);
        assertEq(postBal_admin, preBal_treasury);
    }

    function test_treasury_safeWithdraw_USDT() public {

        // Buy USDT through Uniswap and deposit into Treasury.
        uint tradeAmt = 10 ether;
        address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

        IERC20(WETH).approve(
            address(UNIV2_ROUTER), tradeAmt
        );

        address[] memory path_uni_v2 = new address[](2);

        path_uni_v2[0] = WETH;
        path_uni_v2[1] = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

        IUniswapV2Router01(UNIV2_ROUTER).swapExactTokensForTokens(
            tradeAmt,
            0,
            path_uni_v2,
            address(treasury),  // Send USDT to treasury instead of msg.sender
            block.timestamp + 300
        );

        uint preBal_treasury = IERC20(USDT).balanceOf(address(treasury));
        uint preBal_admin = IERC20(USDT).balanceOf(address(this));

        treasury.safeWithdraw(USDT);

        uint postBal_treasury = IERC20(USDT).balanceOf(address(treasury));
        uint postBal_admin = IERC20(USDT).balanceOf(address(this));

        assertEq(preBal_admin, postBal_treasury);
        assertEq(postBal_admin, preBal_treasury);
    }

    function test_treasury_updateAdmin() public {
        treasury.updateAdmin(address(32));
        assertEq(treasury.admin(), address(32));
    }

    // function test_treasury_setDistributionThreshold() public {
    //     treasury.setDistributionThreshold(1000);

    //     assertEq(treasury.taxTokenDistributionThreshold(), 1000 * 10**taxToken.decimals());
    // }

    // Test automatic taxToken distribution once threshold is set and sufficient taxes accrue in treasury
    function test_treasury_automatedBuyTaxDistribution() public {

        taxToken.modifyWhitelist(address(this), false);

        // set tax distribution
        address[] memory wallets = new address[](2);
        address[] memory convertToAsset = new address[](2);
        uint[] memory percentDistribution = new uint[](2);
        
        wallets[0] = address(12);
        wallets[1] = address(13);
        convertToAsset[0] = WETH;
        convertToAsset[1] = address(taxToken);
        percentDistribution[0] = 50;
        percentDistribution[1] = 50;

        treasury.setTaxDistribution( 
            0, 
            2, 
            wallets, 
            convertToAsset, 
            percentDistribution
        );

        // check balance of treasury
        // emit LogUint("treasury_balance_preTaxThreshold", taxToken.balanceOf(address(treasury)));
        
        // Pre-state check.
        assertEq(IERC20(WETH).balanceOf(address(12)), 0);
        assertEq(taxToken.balanceOf(address(13)), 0);
        assertEq(treasury.taxDistributionThreshold(), 1000 ether);

        // check balance of wallets 12 and 13
        //emit LogUint("wallet_12_balance_postDistribution", taxToken.balanceOf(address(12)));
        //emit LogUint("wallet_13_balance_postDistribution", taxToken.balanceOf(address(13)));

        // setup taxThreshhold
        treasury.setDistributionThreshold(15);

        // get the value of buy taxes accrued before distribution
        (, uint taxType1, ,) = treasury.viewTaxesAccrued();

        // get the tax settings for buy distribution to check individual wallet percentages
        (, , , uint[] memory percentDist) = treasury.viewTaxSettings(0);

        // get distribution percentages for wallets 12 & 13
        uint percentDist_12 = percentDist[0];
        uint percentDist_13 = percentDist[1];

        // transfer taxTokens to treasury which updates taxes accrued to trigger distribution
        xfer_generateFees();

        uint bal = treasury.royaltiesDistributed_WETH(address(12));

        // check balance of treasury for a 0 balance of tokens
        //emit LogUint("treasury_balance_postTaxThreshold", taxToken.balanceOf(address(treasury)));

        // ensure that the appropriate amounts have been distributed to the wallets based upon their distributions
        assertEq(IERC20(WETH).balanceOf(address(12)), bal);
        assertEq(taxToken.balanceOf(address(13)), (taxType1*percentDist_13)/100);
    }

    // Test loss and reset of taxes accrued for tax distribution(s) that are not properly setup
    // The taxes accrued remain in the treasury, but their amounts are reset to 0 without options to withdrawal.
    function testFail_treasury_missingDistributions() public {

        // NOTE:
        // if any tax distributions are NOT set, then the taxes accrued for those distributions will be lost
        // during any call to the "distributeTaxes" function :)

        // setup taxDistribution for buy tax
        address[] memory wallets = new address[](2);
        address[] memory convertToAsset = new address[](2);
        uint[] memory percentDistribution = new uint[](2);
        
        wallets[0] = address(12);
        wallets[1] = address(13);
        convertToAsset[0] = address(taxToken);
        convertToAsset[1] = address(taxToken);
        percentDistribution[0] = 50;
        percentDistribution[1] = 50;

        // tax distribution for buy, but missing tax distributions for sell and transfer.
        treasury.setTaxDistribution( 
            1, 
            2, 
            wallets, 
            convertToAsset, 
            percentDistribution
        );

        // setup taxThreshhold
        treasury.setDistributionThreshold(15);

        // get the amount of transfer & sell taxes accrued before distribution
        (uint taxType0_before, , uint taxType2_before,) = treasury.viewTaxesAccrued();

        //emit LogUint("treasury_balance_preTaxThreshold", taxToken.balanceOf(address(treasury)));

        // exceeds threshold so distribution occurs, buy will not affect sell or transfer taxes accrued
        buy_generateFees();
        
        // get the amount of transfer & sell taxes accrued after distribution
        (uint taxType0_after, , uint taxType2_after,) = treasury.viewTaxesAccrued();

        //emit LogUint("treasury_balance_afterTaxThreshold", taxToken.balanceOf(address(treasury)));
        uint treasuryBalanceAfter = taxToken.balanceOf(address(treasury));

        // amount of taxes accrued for transfer/sell taxes before and after will not be equivalent
        assertEq(taxType0_before, taxType0_after);
        assertEq(taxType2_before, taxType2_after);

        // remaining treasury balance will not be equivalent to the sum of taxes accrued for transfer/sell
        // taxes after distribution because of the reset.
        assertEq(treasuryBalanceAfter, taxType0_after+taxType2_after);
    }

}