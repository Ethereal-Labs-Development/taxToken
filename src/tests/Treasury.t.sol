// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../../lib/ds-test/src/test.sol";
import "./Utility.sol";
import "../TaxToken.sol";
import "../Treasury.sol";

// Import interface.
import { IERC20, IUniswapV2Router01, IWETH } from "../interfaces/InterfacesAggregated.sol";

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
        createActors();

        // Token instantiation.
        taxToken = new TaxToken(
            1000000000,                // Initial liquidity
            'TaxToken',                 // Name of token
            'TAX',                     // Symbol of token
            18,                        // Precision of decimals
            1000000,                   // Max wallet size
            100000                     // Max transaction amount
        );

        treasury = new Treasury(
            address(this), address(taxToken), DAI
        );

        taxToken.setTreasury(address(treasury));


        // Set basisPointsTax for taxType 0 / 1 / 2
        // taxType 0 => Xfer Tax (10%)  => 10% (1wallets, marketing)
        // taxType 1 => Buy Tax (12%)   => 6%/6% (2wallets, use/marketing))
        // taxType 2 => Sell Tax (15%)  => 5%/4%/6% (3wallets, use/marketing/staking)
        taxToken.adjustBasisPointsTax(0, 1000);   // 1000 = 10.00 %
        taxToken.adjustBasisPointsTax(1, 1200);   // 1200 = 12.00 %
        taxToken.adjustBasisPointsTax(2, 1500);   // 1500 = 15.00 %

        
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

        //setProperTaxDistribution_ADMT();
        setTaxDistribution_DAI();
    }

    // Simulate buy (taxType 1).
    function buy_generateFees() public {
        uint tradeAmt = 1 ether;

        IERC20(WETH).approve(
            address(UNIV2_ROUTER), tradeAmt
        );

        address[] memory path_uni_v2 = new address[](2);

        path_uni_v2[0] = WETH;
        path_uni_v2[1] = address(taxToken);

        IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path_uni_v2,
            msg.sender,
            block.timestamp + 300
        );
    }

    // Simulate sell (taxType 2).
    function sell_generateFees() public {
        uint tradeAmt = 10 ether;

        IERC20(address(taxToken)).approve(
            address(UNIV2_ROUTER), tradeAmt
        );

        address[] memory path_uni_v2 = new address[](2);

        path_uni_v2[0] = address(taxToken);
        path_uni_v2[1] = WETH;

        // Documentation on IUniswapV2Router:
        // https://docs.uniswap.org/protocol/V2/reference/smart-contracts/router-02#swapexacttokensfortokens
        IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,           
            0,
            path_uni_v2,
            msg.sender,
            block.timestamp + 300
        );
    }

    // Simulate xfer (taxType 0).
    function xfer_generateFees() public {
        taxToken.transfer(address(69), 1 ether);
    }

    // Initial state check on treasury.
    // Each taxType (0, 1, and 2) should have some greater than 0 value.
    // The sum of all taxes accrued for each taxType should equal taxToken.balanceOf(treasury).
    function test_treasury_initialState() public {
        assert(treasury.amountRoyaltiesWeth() > 0);
        assertEq(treasury.amountRoyaltiesWeth(), IERC20(WETH).balanceOf(address(treasury)));
    }

    // Test require statement fail: require(walletCount == wallets.length).
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
            2, 
            wallets, 
            convertToAsset, 
            percentDistribution
        );
    }

    // Test require statement fail: require(walletCount == convertToAsset.length).
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
            2, 
            wallets, 
            convertToAsset, 
            percentDistribution
        );
    }

    // Test require statement fail: require(walletCount == percentDistribution.length).
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
            2, 
            wallets, 
            convertToAsset, 
            percentDistribution
        );
    }

    // Test require statement fail: require(sumPercentDistribution == 100).
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
        ) = treasury.viewTaxSettings();

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
        ) = treasury.viewTaxSettings();

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

    // TODO: Add descriptions.
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
            2, 
            wallets, 
            convertToAsset, 
            percentDistribution
        );

        uint _preTaxAccrued = treasury.amountRoyaltiesWeth();

        assertEq(treasury.distributeTaxes(), _preTaxAccrued);
    }

    // TODO: Add descriptions.
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
            2, 
            wallets, 
            convertToAsset, 
            percentDistribution
        );

        uint _preTaxAccrued = treasury.amountRoyaltiesWeth();
        
        assertEq(treasury.distributeTaxes(), _preTaxAccrued);
    }


    // This test covers multiple tax generation events (of type 0, 1, 2) and collections.
    function test_treasury_multiple_gens_collections() public {
        treasury.distributeTaxes();
        buy_generateFees();
        treasury.distributeTaxes();
        sell_generateFees();
        treasury.distributeTaxes();
        xfer_generateFees();
        treasury.distributeTaxes();
        sell_generateFees();
        buy_generateFees();
        treasury.distributeTaxes();
        sell_generateFees();
        xfer_generateFees();
        treasury.distributeTaxes();
        buy_generateFees();
        xfer_generateFees();
        treasury.distributeTaxes();
        sell_generateFees();
        buy_generateFees();
        xfer_generateFees();
        treasury.distributeTaxes();
    }
    
    // TODO: Add descriptions.
    function test_view_function_taxesAccrued() public {
        ( uint _amount ) = treasury.viewTaxesAccrued();

        emit LogUint("amount of taxes accrued", _amount);
        assertEq(_amount, IERC20(WETH).balanceOf(address(treasury)));

        // Error: a == b not satisfied [uint]
        // Expected: 102299087242321134 <-- IERC20(WETH).balanceOf(address(treasury))
        // Actual:   120330359447682921 < -- _amount
    }

    // TODO: Add descriptions.
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
            address(treasury),  // Send USDC to treasury instead of msg.sender.
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

    // TODO: Add descriptions.
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
            address(treasury),  // Send DAI to treasury instead of msg.sender.
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

    // TODO: Add descriptions.
    function test_treasury_updateAdmin() public {
        treasury.updateAdmin(address(32));
        assertEq(treasury.admin(), address(32));
    }

    // Experiment with exchangeRateTotal() view function.
    // function test_treasury_exchangeRateTotal() public {

    //     address[] memory path_uni_v2 = new address[](3);

    //     path_uni_v2[0] = address(taxToken);
    //     path_uni_v2[1] = WETH;
    //     path_uni_v2[2] = DAI;

    //     uint taxType0 = treasury.exchangeRateForTaxType(path_uni_v2, 0);
    //     uint taxType1 = treasury.exchangeRateForTaxType(path_uni_v2, 1);
    //     uint taxType2 = treasury.exchangeRateForTaxType(path_uni_v2, 2);

    //     emit Debug('taxType0', taxType0);
    //     emit Debug('taxType1', taxType1);
    //     emit Debug('taxType2', taxType2);

    //     // ├╴Debug("taxType0", 1796310537150394376) (src/Treasury.t.sol:546)
    //     // ├╴Debug("taxType1", 212532665568400683822) (src/Treasury.t.sol:547)
    //     // ├╴Debug("taxType2", 26940783891853202311) (src/Treasury.t.sol:548)

    //     buy_generateFees();
    //     buy_generateFees();
    //     buy_generateFees();

    //     taxType0 = treasury.exchangeRateForTaxType(path_uni_v2, 0);
    //     taxType1 = treasury.exchangeRateForTaxType(path_uni_v2, 1);
    //     taxType2 = treasury.exchangeRateForTaxType(path_uni_v2, 2);

    //     emit Debug('taxType0', taxType0);
    //     emit Debug('taxType1', taxType1);
    //     emit Debug('taxType2', taxType2);

    //     // ├╴Debug("taxType0", 1904533759476995397) (src/Treasury.t.sol:556)
    //     // ├╴Debug("taxType1", 873293553192437130107) (src/Treasury.t.sol:557)
    //     // ├╴Debug("taxType2", 28563774513486153680) (src/Treasury.t.sol:558)

    //     sell_generateFees();
    //     sell_generateFees();
    //     sell_generateFees();

    //     taxType0 = treasury.exchangeRateForTaxType(path_uni_v2, 0);
    //     taxType1 = treasury.exchangeRateForTaxType(path_uni_v2, 1);
    //     taxType2 = treasury.exchangeRateForTaxType(path_uni_v2, 2);

    //     emit Debug('taxType0', taxType0);
    //     emit Debug('taxType1', taxType1);
    //     emit Debug('taxType2', taxType2);

    //     // ├╴Debug("taxType0", 1894496762882612346) (src/Treasury.t.sol:566)
    //     // ├╴Debug("taxType1", 868702596890567721328) (src/Treasury.t.sol:567)
    //     // ├╴Debug("taxType2", 113599069356538056284) (src/Treasury.t.sol:568)

    //     xfer_generateFees();
    //     xfer_generateFees();
    //     xfer_generateFees();

    //     taxType0 = treasury.exchangeRateForTaxType(path_uni_v2, 0);
    //     taxType1 = treasury.exchangeRateForTaxType(path_uni_v2, 1);
    //     taxType2 = treasury.exchangeRateForTaxType(path_uni_v2, 2);

    //     emit Debug('taxType0', taxType0);
    //     emit Debug('taxType1', taxType1);
    //     emit Debug('taxType2', taxType2);

    //     // ├╴Debug("taxType0", 7577747125354401523) (src/Treasury.t.sol:576)
    //     // ├╴Debug("taxType1", 868702596890567721328) (src/Treasury.t.sol:577)
    //     // └╴Debug("taxType2", 113599069356538056284) (src/Treasury.t.sol:578)

    // }

    function setProperTaxDistribution_ADMT() public {

        // Update distribution settings (for sells and transfers).
        address[] memory wallets = new address[](5);
        address[] memory convertToAsset = new address[](5);
        uint[] memory percentDistribution = new uint[](5);
        
        wallets[0] = address(1);
        wallets[1] = address(2);
        wallets[2] = address(3);
        wallets[3] = address(4);
        wallets[4] = address(5);
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

        // Update distribution settings (for buys).
        wallets = new address[](4);
        convertToAsset = new address[](4);
        percentDistribution = new uint[](4);
        
        wallets[0] = address(6);
        wallets[1] = address(7);
        wallets[2] = address(8);
        wallets[3] = address(9);
        convertToAsset[0] = WETH;
        convertToAsset[1] = WETH;
        convertToAsset[2] = WETH;
        convertToAsset[3] = WETH;
        percentDistribution[0] = 40;
        percentDistribution[1] = 20;
        percentDistribution[2] = 20;
        percentDistribution[3] = 20;
        
        treasury.setTaxDistribution(
            4, 
            wallets, 
            convertToAsset, 
            percentDistribution
        );

    }

    function setTaxDistribution_DAI() public {

        address[] memory wallets = new address[](3);
        address[] memory convertToAsset = new address[](3);
        uint[] memory percentDistribution = new uint[](3);
        
        wallets[0] = address(1);
        wallets[1] = address(2);
        wallets[2] = address(3);
        convertToAsset[0] = DAI;
        convertToAsset[1] = DAI;
        convertToAsset[2] = DAI;
        percentDistribution[0] = 20;
        percentDistribution[1] = 20;
        percentDistribution[2] = 60;
        
        treasury.setTaxDistribution(
            3,
            wallets, 
            convertToAsset, 
            percentDistribution
        );
    }

    function test_treasury_distributeTaxes() public {
        treasury.distributeTaxes();
    }

    // NOTE: taxDistribution set in SetUp() -> setTaxDistribution_DAI().
    function test_treasury_DAI_royalties() public {

        //treasury.updateStable(DAI);
        address distributionToken = treasury.stable(); // DAI

        assertEq(IERC20(distributionToken).symbol(), "DAI");
        assertEq(IERC20(distributionToken).decimals(), 18);

        // Pre-State Check.
        uint preBal1 = IERC20(distributionToken).balanceOf(address(1));
        uint preBal2 = IERC20(distributionToken).balanceOf(address(2));
        uint preBal3 = IERC20(distributionToken).balanceOf(address(3));

        assertEq(treasury.distributionsStable(address(1)), 0);
        assertEq(treasury.distributionsStable(address(2)), 0);
        assertEq(treasury.distributionsStable(address(3)), 0);

        // Distribute Royalties
        treasury.distributeTaxes();

        //Post-State Check.
        uint postBal1 = IERC20(distributionToken).balanceOf(address(1));
        uint postBal2 = IERC20(distributionToken).balanceOf(address(2));
        uint postBal3 = IERC20(distributionToken).balanceOf(address(3));

        assertEq(treasury.distributionsStable(address(1)), postBal1 - preBal1);
        assertEq(treasury.distributionsStable(address(2)), postBal2 - preBal2);
        assertEq(treasury.distributionsStable(address(3)), postBal3 - preBal3);

        emit LogUint("Stable Received address(1)", postBal1 - preBal1); // 20%
        emit LogUint("Stable Received address(2)", postBal2 - preBal2); // 20%
        emit LogUint("Stable Received address(3)", postBal3 - preBal3); // 60%

        // ├╴LogUint("Stable Received address(1)", 44172136289620355915)
        // ├╴LogUint("Stable Received address(2)", 44172136289620355915)
        // └╴LogUint("Stable Received address(3)", 132516408868861067746)
    }

    // NOTE: taxDistribution set in SetUp() -> setTaxDistribution_DAI().
    function test_treasury_USDC_royalties() public {
        treasury.updateAdmin(address(dev));
        dev.try_updateStable(address(treasury), USDC);
        
        //treasury.updateStable(DAI);
        address distributionToken = treasury.stable(); // USDC

        assertEq(IERC20(distributionToken).symbol(), "USDC");
        assertEq(IERC20(distributionToken).decimals(), 6);

        // Pre-State Check.
        uint preBal1 = IERC20(distributionToken).balanceOf(address(1));
        uint preBal2 = IERC20(distributionToken).balanceOf(address(2));
        uint preBal3 = IERC20(distributionToken).balanceOf(address(3));

        assertEq(treasury.distributionsStable(address(1)), 0);
        assertEq(treasury.distributionsStable(address(2)), 0);
        assertEq(treasury.distributionsStable(address(3)), 0);

        // Distribute Royalties
        treasury.distributeTaxes();

        //Post-State Check.
        uint postBal1 = IERC20(distributionToken).balanceOf(address(1));
        uint postBal2 = IERC20(distributionToken).balanceOf(address(2));
        uint postBal3 = IERC20(distributionToken).balanceOf(address(3));

        assertEq(treasury.distributionsStable(address(1)), postBal1 - preBal1);
        assertEq(treasury.distributionsStable(address(2)), postBal2 - preBal2);
        assertEq(treasury.distributionsStable(address(3)), postBal3 - preBal3);

        emit LogUint("Stable Received address(1)", postBal1 - preBal1); // 20%
        emit LogUint("Stable Received address(2)", postBal2 - preBal2); // 20%
        emit LogUint("Stable Received address(3)", postBal3 - preBal3); // 60%

        // ├╴LogUint("Stable Received address(1)", 44238246)
        // ├╴LogUint("Stable Received address(2)", 44238246)
        // └╴LogUint("Stable Received address(3)", 132714739)
    }

    // NOTE: taxDistribution set in SetUp() -> setTaxDistribution_DAI().
    function test_treasury_FRAX_royalties() public {
        treasury.updateAdmin(address(dev));
        dev.try_updateStable(address(treasury), FRAX);
        
        //treasury.updateStable(DAI);
        address distributionToken = treasury.stable(); // USDC

        assertEq(IERC20(distributionToken).symbol(), "FRAX");
        assertEq(IERC20(distributionToken).decimals(), 18);

        // Pre-State Check.
        uint preBal1 = IERC20(distributionToken).balanceOf(address(1));
        uint preBal2 = IERC20(distributionToken).balanceOf(address(2));
        uint preBal3 = IERC20(distributionToken).balanceOf(address(3));

        assertEq(treasury.distributionsStable(address(1)), 0);
        assertEq(treasury.distributionsStable(address(2)), 0);
        assertEq(treasury.distributionsStable(address(3)), 0);

        // Distribute Royalties
        treasury.distributeTaxes();

        //Post-State Check.
        uint postBal1 = IERC20(distributionToken).balanceOf(address(1));
        uint postBal2 = IERC20(distributionToken).balanceOf(address(2));
        uint postBal3 = IERC20(distributionToken).balanceOf(address(3));

        assertEq(treasury.distributionsStable(address(1)), postBal1 - preBal1);
        assertEq(treasury.distributionsStable(address(2)), postBal2 - preBal2);
        assertEq(treasury.distributionsStable(address(3)), postBal3 - preBal3);

        emit LogUint("Stable Received address(1)", postBal1 - preBal1); // 20%
        emit LogUint("Stable Received address(2)", postBal2 - preBal2); // 20%
        emit LogUint("Stable Received address(3)", postBal3 - preBal3); // 60%

        // ├╴LogUint("Stable Received address(1)", 43454257034374145510)
        // ├╴LogUint("Stable Received address(2)", 43454257034374145510)
        // └╴LogUint("Stable Received address(3)", 130362771103122436532)
    }


    // ~ Tests For Automated Ryalty Distribution on branch sell-on-sell ~


    // Experiment with exchangeRateForWethToStable() view function.
    function test_treasury_exchangeRateForWethToStable() public {

        address[] memory path_uni_v2 = new address[](2);

        path_uni_v2[0] = WETH;
        path_uni_v2[1] = DAI;

        uint amountWeth0 = treasury.amountRoyaltiesWeth();
        uint amountStable0 = treasury.exchangeRateForWethToStable(path_uni_v2);

        emit Debug('Weth', amountWeth0);
        emit Debug('Stable', amountStable0);

        // ├╴Debug("Weth", 120330359447682921)
        // ├╴Debug("Stable", 158705418105444388209)

        // ETH PRICE = $1,323.56

        buy_generateFees();
        buy_generateFees();
        buy_generateFees();

        uint amountWeth1 = treasury.amountRoyaltiesWeth();
        uint amountStable1 = treasury.exchangeRateForWethToStable(path_uni_v2);

        emit Debug('Weth', amountWeth1);
        emit Debug('Stable', amountStable1);

        assertEq(amountWeth0, amountWeth1);
        assertEq(amountStable0, amountStable1);

        // ├╴Debug("Weth", 120330359447682921)
        // ├╴Debug("Stable", 158705418105444388209)

        sell_generateFees();
        sell_generateFees();
        sell_generateFees();

        uint amountWeth2 = treasury.amountRoyaltiesWeth();
        uint amountStable2 = treasury.exchangeRateForWethToStable(path_uni_v2);

        emit Debug('Weth', amountWeth2);
        emit Debug('Stable', amountStable2);

        // ├╴Debug("Weth", 536454981790053474)
        // ├╴Debug("Stable", 707481075308366014932)

        xfer_generateFees();
        xfer_generateFees();
        sell_generateFees();

        uint amountWeth3 = treasury.amountRoyaltiesWeth();
        uint amountStable3 = treasury.exchangeRateForWethToStable(path_uni_v2);

        emit Debug('Weth', amountWeth3);
        emit Debug('Stable', amountStable3);

        // ├╴Debug("Weth", 554467595413567702)
        // └╴Debug("Stable", 731233702267277927066)

    }

}