//SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import { ITreasury } from "./interfaces/ERC20.sol";

contract TaxToken {
 
    // ---------
    // State Variables
    // ---------

    // ERC20 Basic
    uint256 _totalSupply;
    uint8 private _decimals;
    string private _name;
    string private _symbol;

    // ERC20 Pausable
    bool private _paused;  // ERC20 Pausable state

    // Extras
    address public owner;
    address public adminWallet;
    address public treasury;
    bool public treasurySet;

    // ERC20 Mappings
    mapping(address => uint256) balances;                       // Track balances.
    mapping(address => mapping(address => uint256)) allowed;    // Track allowances. TODO: Consider if rename to allowances().

    // Extras Mappings
    mapping(address => bool) whitelist;         // Any transfer that involves a whitelisted address, will not incur a tax.
    mapping(address => uint) senderTaxType;     // Identifies tax type for msg.sender of transfer() call.
    mapping(address => uint) receiverTaxType;   // Identifies tax type for _to of transfer() call.
    mapping(uint => uint) basisPointsTax;       // Mapping between taxType and basisPoints (taxed).

    // TODO: Add-in blacklist.
    

    // -----------
    // Constructor
    // -----------

    //Instead of hard coding, you can pass things like supply, sumbol, ect through the constructor
    //upon deployment to reduce LOC. *Limit of 12 inpus per function
    constructor(
        uint totalSupplyInput, 
        string memory nameInput, 
        string memory symbolInput, 
        uint8 decimalsInput,
        address adminWalletInput
    ) {

        _paused = false;                            // ERC20 Pausable global state variable, initial state is not paused ("unpaused").
        _totalSupply = totalSupplyInput;
        _name = nameInput;
        _symbol = symbolInput;
        _decimals = decimalsInput;

        owner = msg.sender;                         // The "owner" is the "admin" of this contract.
        balances[msg.sender] = totalSupplyInput;    // Initial liquidity, allocated entirely to "owner". 
        adminWallet = adminWalletInput;             // TODO: Identify what this variable is used for. Remove if unnecessary.
    }
 
    // ---------
    // Modifiers
    // ---------

    /// @dev whenNotPaused() is used if the contract MUST be paused ("paused").
    modifier whenNotPaused() {
        require(!paused(), "ERR: Contract is currently paused.");
        _;
    }

    /// @dev whenPaused() is used if the contract MUST NOT be paused ("unpaused").
    modifier whenPaused() {
        require(paused(), "ERR: Contract is not currently paused.");
        _;
    }
    
    /// @dev onlyOwner() is used if msg.sender MUST be owner.
    modifier onlyOwner {
       require(msg.sender == owner, "ERR: TaxToken.sol, onlyOwner()"); 
       _;   //_; acts as a "continue after this" specifically for modifiers
    }

    // ------
    // Events
    // ------

    event LogUint(string s, uint u);       /// @notice This is a logging function for HEVM testing.
    event LogAddy(string s, address a);    /// @notice This is a logging function for HEVM testing.

    event Paused(address account);      /// @dev Emitted when the pause is triggered by `account`.
    event Unpaused(address account);    /// @dev Emitted when the pause is lifted by `account`.

    /// @dev Emitted when approve() is called.
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);   
 
    /// @dev Emitted upon transfer of tokens.
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event TransferTax(address indexed _from, address indexed _to, uint256 _value, uint256 _taxType);

    
    /// @notice Pause the contract, blocks transfer() and transferFrom().
    /// @dev Contract must be paused to call this, caller must be "owner".
    function pause() public onlyOwner whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    /// @notice Unpause the contract.
    function unpause() public onlyOwner whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }

    /// @return _paused Indicates whether the contract is paused (true) or not (false).
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    function setTreasury(address _treasury) public onlyOwner {
        require(!treasurySet);
        treasury = _treasury;
        treasurySet = true;
    }

    function updateSenderTaxType(address _sender, uint _taxType) public onlyOwner {
        require(_taxType < 3);
        senderTaxType[_sender] = _taxType;
    }

    function updateReceiverTaxType(address _receiver, uint _taxType) public onlyOwner {
        require(_taxType < 3);
        receiverTaxType[_receiver] = _taxType;
    }

    function adjustBasisPointsTax(uint _taxType, uint _bpt) public onlyOwner {
        basisPointsTax[_taxType] = _bpt;
        // TODO: constrict range, _bpt <= 10000
        // TODO: update in Treasury the division (100000 => 10000)
    }

    function transferOwnership(address _owner) public onlyOwner {
        //_ for parameter input for functions, and non for variables
        owner = _owner;
    }


    // TODO: Implement functions below.
    
    function permanentlyRemoveTaxes() public onlyOwner {
        // TODO: Reduce taxType 0/1/2/ down to 0
        // TODO: transferOwnership to address(0)
    }

    function modifyWhitelist() public onlyOwner {
        // TODO: Some checks if they are currently on Blacklist.
    }

    function modifyBlacklist() public onlyOwner {
        // TODO: Some checks if they are currently on Whitelist.
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }
 
    function approve(address _spender, uint256 _amount) public returns (bool success) {
        allowed[msg.sender][_spender] = _amount;
        emit Approval(msg.sender, _spender, _amount);
        return true;
    }
 
    // transfer function
    function transfer(address _to, uint256 _amount) public whenNotPaused returns (bool success)
    {   

        // TODO: Check for blacklist msg.sender / _to.

        // Tax Type 0 => Xfer Tax (10%) => 10% (1wallets, marketing)
        // Tax Type 1 => Buy Tax (12%) => 6%/6% (2wallets, use/marketing))
        // Tax Type 2 => Sell Tax (12%) => 2%/4%/6% (3wallets, use/marketing/staking)
        uint _taxType;

        emit LogUint('_amount', _amount);

        if (balances[msg.sender] >= _amount) {

            if (!whitelist[_to] && !whitelist[msg.sender]) {
                
                // Determine, if not the default 0, tax type of transfer.
                if (senderTaxType[msg.sender] != 0) {
                    _taxType = senderTaxType[msg.sender];
                }

                if (receiverTaxType[_to] != 0) {
                    _taxType = receiverTaxType[_to];
                }

                // Calculate taxAmt and sendAmt
                uint _taxAmt = _amount * basisPointsTax[_taxType] / 100000;
                uint _sendAmt = _amount * (100000 - basisPointsTax[_taxType]) / 100000;

                emit LogUint('_taxAmt', _taxAmt);
                emit LogUint('_sendAmt', _sendAmt);
                emit LogUint('_taxType', _taxType);
                emit LogUint('basisPointsTax[_taxType]', basisPointsTax[_taxType]);

                // Pre-state logs.
                emit LogUint('pre_balances[msg.sender]', balances[msg.sender]);
                emit LogUint('pre_balances[_to]', balances[_to]);
                emit LogUint('pre_balances[treasury]', balances[treasury]);

                balances[msg.sender] -= _amount;
                balances[_to] += _sendAmt;
                balances[treasury] += _taxAmt;

                // Post-state logs.
                emit LogUint('post_balances[msg.sender]', balances[msg.sender]);
                emit LogUint('post_balances[_to]', balances[_to]);
                emit LogUint('post_balances[treasury]', balances[treasury]);

                
                emit LogAddy('treasury', treasury);

                require(_taxAmt + _sendAmt == _amount, "Critical error, math.");
            
                // Update accounting in Treasury.
                ITreasury(treasury).updateTaxesAccrued(
                    _taxType, _taxAmt
                );
                
                emit Transfer(msg.sender, _to, _sendAmt);
                emit TransferTax(msg.sender, treasury, _taxAmt, _taxType);
                return true;

            }

            else {
                balances[msg.sender] -= _amount;
                balances[_to] += _amount;
            
                emit Transfer(msg.sender, _to, _amount);
                return true;
            }
        }
        else {
            return false;
        }
    }
 
    function transferFrom(address _from, address _to, uint256 _amount) public whenNotPaused returns (bool success) {
        if (balances[_from] >= _amount && allowed[_from][msg.sender] >= _amount && _amount > 0 && balances[_to] + _amount > balances[_to]) {
            balances[_from] -= _amount;
            balances[_to] += _amount;
            emit Transfer(_from, _to, _amount);
            return true;
        }
        else {
            return false;
        }
    }
 
    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }
    
}
