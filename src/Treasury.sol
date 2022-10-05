//SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import { IERC20, IUniswapV2Router02, IWETH } from "./interfaces/InterfacesAggregated.sol";


/// @notice The treasury is responsible for escrow of TaxToken fee's.
///         The treasury handles accounting, for what's owed to different groups.
///         The treasury handles distribution of TaxToken fees to different groups.
///         The admin can modify how TaxToken fees are distributed (the TaxDistribution struct).
contract Treasury {
 
    // ---------------
    // State Variables
    // ---------------

    /// @dev The token that fees are taken from, and what is held in escrow here.
    address public taxToken;

    /// @dev The stablecoin that is distributed via royalties.
    address public stable;

    /// @dev The administrator of accounting and distribution settings.
    address public admin;

    uint256 public amountRoyaltiesWeth;
    
    address public constant UNIV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    address public WETH;

    // Mappings

    /// @notice Handles the internal accounting for how much taxToken is owed to each taxType.
    /// @dev    e.g. 10,000 taxToken owed to taxType 0 => taxTokenAccruedForTaxType[0] = 10000 * 10**18.
    ///         taxType 0 => Xfer Tax
    ///         taxType 1 => Buy Tax
    ///         taxType 2 => Sell Tax
    mapping(uint => uint) public taxTokenAccruedForTaxType; //

    mapping(uint => uint) public WethAccruedForTaxType; //

    /// @dev Tracks amount of stablecoin distributed to recipients.
    mapping(address => uint256) public distributionsStable;

    /// @dev taxSettings.
    TaxDistribution public taxSettings;

    // Structs

    /// @notice Manages how TaxToken is distributed for a given taxType.
    ///         Variables:
    ///           walletCount           => The number of wallets to distribute fees to.
    ///           wallets               => The addresses to distribute fees (maps with convertToAsset and percentDistribution).
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

    /// @notice Initializes the Treasury.
    /// @param  _admin      The administrator of the contract.
    /// @param  _taxToken   The taxToken (ERC-20 asset) which accumulates in this Treasury.
    constructor(address _admin, address _taxToken, address _stable) {
        admin = _admin;
        taxToken = _taxToken;
        stable = _stable;

        WETH = IUniswapV2Router02(UNIV2_ROUTER).WETH();
    }


    // ---------
    // Modifiers
    // ---------

    /// @dev Enforces msg.sender is admin.
    modifier isAdmin {
        require(msg.sender == admin);
        _;
    }

    /// @dev Enforces msg.sender is taxToken.
    modifier isTaxToken {
        require(msg.sender == taxToken);
        _;
    }



    // ------
    // Events
    // ------

    /// @dev Emitted when transferOwnership() is completed.
    event OwnershipTransferred(address indexed currentAdmin, address indexed newAdmin);

    /// @dev Emitted when royalties are distributed via distributeTaxes()
    event RoyaltiesDistributed(address indexed recipient, uint amount, address asset);

    /// @dev Emitted when the stable state variable is updated via updateStable()
    event StableUpdated(address currentStable, address newStable);

    /// @dev Emitted when the treasury receives royalties
    event RoyaltiesReceived(uint256 amountReceived, uint256 newTotal);

 

    // ---------
    // Functions
    // ---------

    /// @notice Increases _amt of taxToken allocated to _taxType.
    /// @dev    Only callable by taxToken.
    /// @param  _amt The amount of taxToken going to taxType.
    function updateTaxesAccrued(uint _amt) isTaxToken external {
        amountRoyaltiesWeth += _amt;
        emit RoyaltiesReceived(_amt, amountRoyaltiesWeth);
        //taxTokenAccruedForTaxType[_taxType] += _amt;
    }

    function viewTaxesAccrued() external view returns (uint _amountAccrued) {
        return amountRoyaltiesWeth;
    }

    /// @notice This function modifies the distribution settings for all taxes.
    /// @dev    Only callable by Admin.
    /// @param  _walletCount The number of wallets to distribute across.
    /// @param  _wallets The address of wallets to distribute fees across.
    /// @param  _convertToAsset The asset to convert taxToken to, prior to distribution.
    /// @param  _percentDistribution The percentage (corresponding with wallets) to distribute taxes to of overall amount owed for taxType.
    function setTaxDistribution(
        uint _walletCount,
        address[] calldata _wallets,
        address[] calldata _convertToAsset,
        uint[] calldata _percentDistribution
    ) isAdmin external {

        // Pre-check that supplied values have equal lengths.
        require(_walletCount == _wallets.length, "Treasury.sol::setTaxDistribution(), walletCount length != wallets.length");
        require(_walletCount == _convertToAsset.length, "Treasury.sol::setTaxDistribution(), walletCount length != convertToAsset.length");
        require(_walletCount == _percentDistribution.length, "Treasury.sol::setTaxDistribution(), walletCount length != percentDistribution.length");

        // Enforce sum(percentDistribution) = 100;
        uint sumPercentDistribution;
        for(uint i = 0; i < _walletCount; i++) {
            sumPercentDistribution += _percentDistribution[i];
        }
        require(sumPercentDistribution == 100, "Treasury.sol::setTaxDistribution(), sumPercentDistribution != 100");

        // Update taxSettings for taxType.
        taxSettings = TaxDistribution(
            _walletCount,
            _wallets,
            _convertToAsset,
            _percentDistribution
        );
    }

    /// @notice Distributes taxes for given taxType.
    function distributeTaxes() external returns(uint256 _amountToDistribute) {

        uint256 _amountToDistribute = amountRoyaltiesWeth;
        
        if (_amountToDistribute > 0) {

            amountRoyaltiesWeth = 0;

            assert(IERC20(WETH).approve(address(UNIV2_ROUTER), _amountToDistribute));

            address[] memory path_uni_v2 = new address[](2);

            path_uni_v2[0] = WETH;
            path_uni_v2[1] = stable;

            IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokens(
                _amountToDistribute,           
                0,
                path_uni_v2,
                address(this),
                block.timestamp + 30000
            );

            uint balanceStable = IERC20(stable).balanceOf(address(this));

            for (uint i = 0; i < taxSettings.wallets.length; i++) {
                uint amt = balanceStable * taxSettings.percentDistribution[i] / 100;

                assert(IERC20(stable).transfer(taxSettings.wallets[i], amt));

                distributionsStable[taxSettings.wallets[i]] += amt;
                emit RoyaltiesDistributed(taxSettings.wallets[i], amt, stable);
            }
        }

        return _amountToDistribute;
    }

    /// @notice Helper view function for taxSettings.
    /// @return uint256    num of wallets in distribution.
    /// @return address[]  array of wallets in distribution.
    /// @return address[]  array of assets to be converted to during distribution to it's respective wallet.
    /// @return uint[]     array of distribution, all uints must add up to 100.
    function viewTaxSettings() external view returns(uint256, address[] memory, address[] memory, uint[] memory) {
        return (
            taxSettings.walletCount,
            taxSettings.wallets,
            taxSettings.convertToAsset,
            taxSettings.percentDistribution
        );
    }

    /// @notice Withdraw a non-taxToken from the treasury.
    /// @dev    Reverts if token == taxtoken.
    /// @dev    Only callable by Admin.
    /// @param  _token The token to withdraw from the treasury.
    function safeWithdraw(address _token) external isAdmin {
        if (_token == WETH) { amountRoyaltiesWeth = 0; }
        assert(IERC20(_token).transfer(msg.sender, IERC20(_token).balanceOf(address(this))));
    }

    /// @notice Change the admin for the treasury.
    /// @dev    Only callable by Admin.
    /// @param  _admin New admin address.
    function updateAdmin(address _admin) external isAdmin {
        require(_admin != address(0), "Treasury.sol::updateAdmin(), _admin == address(0)");
        emit OwnershipTransferred(admin, _admin);
        admin = _admin;
    }

    /// @notice Change the stable value of the treasury distriubution.
    /// @dev    Only callable by Admin.
    /// @param  _stable New stablecoin address.
    function updateStable(address _stable) external isAdmin {
        require(_stable != stable, "Treasury.sol::updateStable() value already set");
        emit StableUpdated(stable, _stable);
        stable = _stable;
    }
    
    /// @notice View function for exchanging fees collected for given taxType.
    /// @param  _path The path by which taxToken is converted into a given asset (i.e. taxToken => DAI => LINK).
    /// @param  _taxType The taxType to be exchanged.
    function exchangeRateForTaxType(address[] memory _path, uint _taxType) external view returns(uint256) {
        return IUniswapV2Router02(UNIV2_ROUTER).getAmountsOut(
            taxTokenAccruedForTaxType[_taxType], 
            _path
        )[_path.length - 1];
    }

    /// @notice View function for exchanging fees collected for given taxType.
    /// @param  _path The path by which taxToken is converted into a given asset (i.e. taxToken => DAI => LINK).
    function exchangeRateForWethToStable(address[] memory _path) external view returns(uint256) {
        return IUniswapV2Router02(UNIV2_ROUTER).getAmountsOut(
            amountRoyaltiesWeth, 
            _path
        )[_path.length - 1];
    }
}
