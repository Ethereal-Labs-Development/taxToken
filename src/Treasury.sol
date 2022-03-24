//SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

contract Treasury {
 
    // Collect taxes, hold them in escrow.
    address taxToken;
    address admin;

    // 3 Types of Taxes

    // 0 = Transfer Tax
    // 1 = Buy Tax
    // 2 = Sell Tax

    // Mapping between type of tax, and the balance of taxToken.
    mapping(uint => uint) taxAllocation;

    struct TaxDistribution {
        uint walletCount;
        address[] wallets;
        uint[] percentDistribution;
        bool[] convertToEth;
    }

    // Mapping of struct to TaxDistribution
    mapping(uint => TaxDistribution) taxSettings;

    modifier isAdmin {
        require(msg.sender == admin);
        _;
    }

    modifier isTaxToken {
        require(msg.sender == taxToken);
        _;
    }

    constructor(address _admin, address _taxToken) {
        admin = _admin;
        taxToken = _taxToken;
    }

    function updateTaxDistribution(
        uint taxType,
        uint walletCount,
        address[] memory wallets,
        uint[] memory percentDistribution,
        bool[] memory convertToEth
    ) isAdmin public {
        taxSettings[taxType] = TaxDistribution(
            walletCount,
            wallets,
            percentDistribution,
            convertToEth
        );
    }

    // Tax Type 0 => Xfer Tax (10%) => 10% (1wallets, marketing)
    // Tax Type 1 => Buy Tax (12%) => 6%/6% (2wallets, use/marketing))
    // Tax Type 2 => Sell Tax (12%) => 2%/4%/6% (3wallets, use/marketing/staking)
    function distributeTaxes(uint _taxType, uint _amt) isAdmin public returns(bool) {
        require(taxAllocation[_taxType] >= _amt, "Insufficient taxes allocated to taxType");
        // Decrement accounting first.
        taxAllocation[_taxType] -= _amt;
        // Handle transfer / liquidation second.
        return true;
    }

    // TEMPORARY (REMOVE LATER)
    event LogUint(string s, uint u);
    event LogAddy(string s, address a);

    function updateTaxesAccrued(uint _taxType, uint _amt) isTaxToken public {
        taxAllocation[_taxType] += _amt;
    }

}
