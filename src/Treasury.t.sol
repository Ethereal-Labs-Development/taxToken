// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../lib/ds-test/src/test.sol";
import "./Utility.sol";

// Import sol file
import "./TaxToken.sol";
import "./Treasury.sol";

// Import interface.
import { IERC20, IUniswapV2Router01, IWETH } from "./interfaces/ERC20.sol";

contract TaxTokenTest is Utility {

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
            1000000000 ether,           // Initial liquidity
            'ProveZero',                // Name of token.
            'PROZ',                     // Symbol of token.
            18,                         // Precision of decimals.
            1000000,                    // Max wallet size
            100000,                     // Max transaction amount 
            address(this)               // The "owner" / "admin" of the contract.
        );

        treasury = new Treasury(
            address(this), address(taxToken)
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
        taxToken.updateSenderTaxType(UNIV2_PAIR, 1);
        taxToken.updateReceiverTaxType(UNIV2_PAIR, 2);

        // Simulate sell (taxType 2)

        uint tradeAmt = 10 ether;

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
            msg.sender,
            block.timestamp + 300
        );
        
        // Simulate buy (taxType 1)

        tradeAmt = 1 ether;

        IERC20(WETH).approve(
            address(UNIV2_ROUTER), tradeAmt
        );

        path_uni_v2 = new address[](2);

        path_uni_v2[0] = WETH;
        path_uni_v2[1] = address(taxToken);

        uint[] memory amounts = IUniswapV2Router01(UNIV2_ROUTER).getAmountsOut(
            tradeAmt, 
            path_uni_v2
        );

        IUniswapV2Router01(UNIV2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tradeAmt,
            0,
            path_uni_v2,
            msg.sender,
            block.timestamp + 300
        );

        // Simulate xfer (taxType 0)

        taxToken.transfer(address(0), 1 ether);

    }

    function test_treasury_initialState() public {
        emit LogUint("taxTokenAccruedForTaxType[0]", treasury.taxTokenAccruedForTaxType(0));
        emit LogUint("taxTokenAccruedForTaxType[1]", treasury.taxTokenAccruedForTaxType(1));
        emit LogUint("taxTokenAccruedForTaxType[2]", treasury.taxTokenAccruedForTaxType(2));
    }

}