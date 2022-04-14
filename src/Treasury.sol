//SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

/// @dev    The treasury is responsible for escrow of TaxToken fee's.
///         The treasury handles accounting, for what's owed to different groups.
///         The treasury handles distribution of TaxToken fees to different groups.
///         The admin can modify how TaxToken fees are distributed (the TaxDistribution struct).
contract Treasury {
 
    // ---------------
    // State Variables
    // ---------------

    address taxToken;   /// @dev The token that fees are taken from, and what is held in escrow here.
    address admin;      /// @dev The administrator of accounting and distribution settings.

    /// @dev    Handles the internal accounting for how much taxToken is owed to each taxType.
    /// @notice e.g. 10,000 taxToken owed to taxType 0 => taxTokenAccruedForTaxType[0] = 10000 * 10**18
    mapping(uint => uint) taxTokenAccruedForTaxType;

    mapping(uint => TaxDistribution) taxSettings;   /// @dev Mapping of taxType to TaxDistribution struct.
 
    /// @dev    Manages how TaxToken is distributed for a given taxType.
    ///         Variables:
    ///           walletCount           => The number of wallets to distribute fees to.
    ///           wallets               => The addresses to distribute fees (maps with convertToAsset and percentDistribution)
    ///           convertToAsset        => The asset to pre-convert taxToken to prior to distribution (if same as taxToken, no conversion executed).
    ///           percentDistribution   => The percentage of taxToken accrued for taxType to distribute.
    struct TaxDistribution {
        uint walletCount;
        address[] wallets;
        address[] convertToAsset;
        uint[] percentDistribution;
    }



    // -----------
    // Constructor
    // -----------

    /// @dev    Initializes the Treasury.
    /// @param  _admin      The administrator of the contract.
    /// @param  _taxToken   The taxToken (ERC-20 asset) which accumulates in this Treasury.
    constructor(address _admin, address _taxToken) {
        admin = _admin;
        taxToken = _taxToken;
    }


 
    // ---------
    // Modifiers
    // ---------

    /// @dev    Enforces msg.sender is admin.
    modifier isAdmin {
        require(msg.sender == admin);
        _;
    }

    /// @dev    Enforces msg.sender is taxToken.
    modifier isTaxToken {
        require(msg.sender == taxToken);
        _;
    }



    // ------
    // Events
    // ------
    
    event LogUint(string s, uint u);        /// @dev HEVM logging tool for uint.
    event LogAddy(string s, address a);     /// @dev HEVM logging tool for address.



    // ---------
    // Functions
    // ---------

    /// @dev    Increases _amt of taxToken allocated to _taxType.
    /// @param  taxType The taxType to allocate more taxToken to for distribution.
    /// @param  amt The amount of taxToken going to taxType.
    /// @notice Only callable by taxToken.
    function updateTaxesAccrued(uint taxType, uint amt) isTaxToken public {
        taxTokenAccruedForTaxType[taxType] += amt;
    }

    // Tax Type 0 => Xfer Tax (10%) => 10% (1wallets, marketing)
    // Tax Type 1 => Buy Tax (12%) => 6%/6% (2wallets, use/marketing))
    // Tax Type 2 => Sell Tax (12%) => 2%/4%/6% (3wallets, use/marketing/staking)

    /**
        struct TaxDistribution {
            uint walletCount;
            address[] wallets;
            address[] convertToAsset;
            uint[] percentDistribution;
        }
    */

    /// @dev    This function modifies the distribution settings for a given taxType.
    /// @notice Only callable by Admin.
    ///         A distribution must be enforced, prior to the change.
    /// @param  taxType The taxType to update settings for.
    /// @param  walletCount The number of wallets to distribute across.
    /// @param  wallets The address of wallets to distribute fees across.
    /// @param  convertToAsset The asset to convert taxToken to, prior to distribution.
    /// @param  percentDistribution The percentage (corresponding with wallets) to distribute taxes to of overall amount owed for taxType.
    function setTaxDistribution(
        uint taxType,
        uint walletCount,
        address[] memory wallets,
        address[] memory convertToAsset,
        uint[] memory percentDistribution
    ) isAdmin public {

        // TODO: Require walletCount = wallets.length
        // TODO: Require walletCount = converToAsset.length
        // TODO: Require walletCount = percentDistribution.length
        // TODO: Require sum(percentDistribution) = 100

        // TODO: Do we check if asset in convertToAsset is available via Uniswap V2.

        // taxSettings[taxType] = TaxDistribution(
        //     walletCount,
        //     wallets,
        //     convertToAsset,
        //     percentDistribution
        // );
    }

    /// @dev    Distributes taxes for given taxType.
    /// @param  taxType The taxType to distribute.
    function distributeTaxes(uint taxType) public {
        
        // TODO: Consider implementing Uniswap V2 / V3 versions for Treasury (for future clients).

        // TODO: taxTokenAccruedForTaxType[taxType] decreased to 0, save it in local value here.

        // TODO: Loop through each wallet in taxType and distribute the taxToken in given percentage, do conversion if necessary.

    }

    /// @dev    Distributes taxes for all taxTypes.
    function distributeAllTaxes() public {
        distributeTaxes(0);
        distributeTaxes(1);
        distributeTaxes(2);
    }


    /// @dev    Distributes all taxToken to given address and resets accounting variables.
    function cleanse() public { }

}
