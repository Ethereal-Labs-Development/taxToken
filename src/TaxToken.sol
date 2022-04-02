//SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import { ITreasury } from "./interfaces/ERC20.sol";

contract TaxToken {
 
    // ---------------
    // State Variables
    // ---------------

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
    bool public taxesRemoved;   // Once true, taxes are permanently set to 0 and CAN NOT be increased in the future.
    uint256 public maxWalletSize;
    uint256 public maxTxAmount;

    // ERC20 Mappings
    mapping(address => uint256) balances;                       // Track balances.
    mapping(address => mapping(address => uint256)) allowed;    // Track allowances.

    // Extras Mappings
    mapping(address => bool) public isBlacklisted;     // If an address is blacklisted, they cannot transact
    mapping(address => bool) public whitelist;         // Any transfer that involves a whitelisted address, will not incur a tax.
    mapping(address => uint) senderTaxType;     // Identifies tax type for msg.sender of transfer() call.
    mapping(address => uint) receiverTaxType;   // Identifies tax type for _to of transfer() call.
    mapping(uint => uint) public basisPointsTax;       // Mapping between taxType and basisPoints (taxed).


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
        uint256 maxWalletSizeInput,                  // for MaxWalletSize and MaxTxAmount just input the desired non decimal multiple number -
        uint256 maxTxAmountInput,                    // ie: 1000 tokens instead of 1000 * 10**Decimal
        address adminWalletInput

    ) {

        _paused = false;                            // ERC20 Pausable global state variable, initial state is not paused ("unpaused").
        _totalSupply = totalSupplyInput;
        _name = nameInput;
        _symbol = symbolInput;
        _decimals = decimalsInput;

        owner = msg.sender;                         // The "owner" is the "admin" of this contract.
        balances[msg.sender] = totalSupplyInput;    // Initial liquidity, allocated entirely to "owner".
        maxWalletSize = (maxWalletSizeInput * 10**_decimals);
        maxTxAmount = (maxTxAmountInput * 10**_decimals);      
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
       _;
    }



    // ------
    // Events
    // ------

    event LogUint(string s, uint u);        /// @notice This is a logging function for HEVM testing.
    event LogAddy(string s, address a);     /// @notice This is a logging function for HEVM testing.
    event LogString(string s);              /// @notice This is used to log basic strings for HEVM testing.

    event Paused(address account);          /// @dev Emitted when the pause is triggered by `account`.
    event Unpaused(address account);        /// @dev Emitted when the pause is lifted by `account`.

    /// @dev Emitted when approve() is called.
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);   
 
    /// @dev Emitted during transfer() or transferFrom().
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event TransferTax(address indexed _from, address indexed _to, uint256 _value, uint256 _taxType);



    // ---------
    // Functions
    // ---------


    // ~ ERC20 View ~
    
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
 
    // ~ ERC20 transfer(), transferFrom(), approve() ~

    function approve(address _spender, uint256 _amount) public returns (bool success) {
        allowed[msg.sender][_spender] = _amount;
        emit Approval(msg.sender, _spender, _amount);
        return true;
    }
 
    function transfer(address _to, uint256 _amount) public whenNotPaused returns (bool success) {   

        // taxType 0 => Xfer Tax (10%)  => 10% (1wallets, marketing)
        // taxType 1 => Buy Tax (12%)   => 6%/6% (2wallets, use/marketing))
        // taxType 2 => Sell Tax (15%)  => 5%/4%/6% (3wallets, use/marketing/staking)
        uint _taxType;
        
        emit LogAddy('msg.sender', msg.sender);
        emit LogAddy('_to', _to);
        emit LogUint('_amount', _amount);

        if (balances[msg.sender] >= _amount && (!isBlacklisted[msg.sender] && !isBlacklisted[_to])) {

            // Take a tax from them if neither party is whitelisted.
            if (!whitelist[_to] && !whitelist[msg.sender] && _amount <= maxTxAmount) {

                // Determine, if not the default 0, tax type of transfer.
                if (senderTaxType[msg.sender] != 0) {
                    _taxType = senderTaxType[msg.sender];
                }

                if (receiverTaxType[_to] != 0) {
                    _taxType = receiverTaxType[_to];
                }

                // Calculate taxAmt and sendAmt
                uint _taxAmt = _amount * basisPointsTax[_taxType] / 10000;
                uint _sendAmt = _amount * (10000 - basisPointsTax[_taxType]) / 10000;

                if (balances[_to] + _sendAmt <= maxWalletSize) {

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

                    require(_taxAmt + _sendAmt >= _amount * 999999999 / 1000000000, "Critical error, math.");
                
                    // Update accounting in Treasury.
                    ITreasury(treasury).updateTaxesAccrued(
                        _taxType, _taxAmt
                    );
                    
                    emit Transfer(msg.sender, _to, _sendAmt);
                    emit TransferTax(msg.sender, treasury, _taxAmt, _taxType);

                    return true;
                }

                else {
                    return false;
                }

            }

            else if (!whitelist[_to] && !whitelist[msg.sender] && _amount > maxTxAmount) {
                return false;
            }

            else {
                balances[msg.sender] -= _amount;
                balances[_to] += _amount;
                emit LogString("TaxToken.sol transfer() no taxation occurred");
                emit Transfer(msg.sender, _to, _amount);
                return true;
            }
        }
        else {
            return false;
        }
    }
 
    function transferFrom(address _from, address _to, uint256 _amount) public whenNotPaused returns (bool success) {

        // Tax Type 0 => Xfer Tax (10%) => 10% (1wallets, marketing)
        // Tax Type 1 => Buy Tax (12%) => 6%/6% (2wallets, use/marketing))
        // Tax Type 2 => Sell Tax (12%) => 2%/4%/6% (3wallets, use/marketing/staking)
        uint _taxType;
        
        emit LogAddy('msg.sender', msg.sender);
        emit LogAddy('_from', _from);
        emit LogAddy('_to', _to);
        emit LogUint('_amount', _amount);

        if (
            balances[_from] >= _amount && 
            allowed[_from][msg.sender] >= _amount && 
            _amount > 0 && balances[_to] + _amount > balances[_to] && 
            _amount <= maxTxAmount && (!isBlacklisted[_from] && !isBlacklisted[_to])
        ) {
            
            // Reduce allowance.
            allowed[_from][msg.sender] -= _amount;

            // Take a tax from them if neither party is whitelisted.
            if (!whitelist[_to] && !whitelist[_from] && _amount <= maxTxAmount) {

                // Determine, if not the default 0, tax type of transfer.
                if (senderTaxType[_from] != 0) {
                    _taxType = senderTaxType[_from];
                }

                if (receiverTaxType[_to] != 0) {
                    _taxType = receiverTaxType[_to];
                }

                // Calculate taxAmt and sendAmt
                uint _taxAmt = _amount * basisPointsTax[_taxType] / 10000;
                uint _sendAmt = _amount * (10000 - basisPointsTax[_taxType]) / 10000;

                // TODO: Check pre/post allowance, confirm if needs to decrease or not.

                if (balances[_to] + _sendAmt <= maxWalletSize) {

                    emit LogUint('_taxAmt', _taxAmt);
                    emit LogUint('_sendAmt', _sendAmt);
                    emit LogUint('_taxType', _taxType);
                    emit LogUint('basisPointsTax[_taxType]', basisPointsTax[_taxType]);

                    // Pre-state logs.
                    emit LogUint('pre_allowances[_from][msg.sender]', allowance(_from, msg.sender));
                    emit LogUint('pre_balances[_from]', balances[_from]);
                    emit LogUint('pre_balances[_to]', balances[_to]);
                    emit LogUint('pre_balances[treasury]', balances[treasury]);

                    balances[_from] -= _amount;
                    balances[_to] += _sendAmt;
                    balances[treasury] += _taxAmt;

                    // Post-state logs.
                    emit LogUint('post_allowances[_from][msg.sender]', allowance(_from, msg.sender));
                    emit LogUint('post_balances[_from]', balances[_from]);
                    emit LogUint('post_balances[_to]', balances[_to]);
                    emit LogUint('post_balances[treasury]', balances[treasury]);
                    
                    emit LogAddy('treasury', treasury);

                    require(_taxAmt + _sendAmt == _amount, "Critical error, math.");
                
                    // Update accounting in Treasury.
                    ITreasury(treasury).updateTaxesAccrued(
                        _taxType, _taxAmt
                    );
                    
                    emit Transfer(_from, _to, _sendAmt);
                    emit TransferTax(_from, treasury, _taxAmt, _taxType);

                    return true;
                }
                
                else {
                    return false;
                }

            }

            else if (!whitelist[_to] && !whitelist[_from] && _amount > maxTxAmount) {
                return false;
            }

            // Skip taxation if either party is whitelisted (_from or _to).
            else {
                balances[_from] -= _amount;
                balances[_to] += _amount;
                emit LogString("TaxToken.sol transferFrom() no taxation occurred");
                emit Transfer(_from, _to, _amount);
                return true;
            }

        }
        else {
            return false;
        }
    }
    
    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }


    // ~ ERC20 Pausable ~

    /// @notice Pause the contract, blocks transfer() and transferFrom().
    /// @dev Contract MUST NOT be paused to call this, caller must be "owner".
    function pause() public onlyOwner whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    /// @notice Unpause the contract.
    /// @dev Contract MUST be puased to call this, caller must be "owner".
    function unpause() public onlyOwner whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }

    /// @return _paused Indicates whether the contract is paused (true) or not (false).
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    
    // ~ TaxType & Fee Management ~

    function updateSenderTaxType(address _sender, uint _taxType) public onlyOwner {
        require(_taxType < 3);
        senderTaxType[_sender] = _taxType;
    }

    function updateReceiverTaxType(address _receiver, uint _taxType) public onlyOwner {
        require(_taxType < 3);
        receiverTaxType[_receiver] = _taxType;
    }

    function adjustBasisPointsTax(uint _taxType, uint _bpt) public onlyOwner {
        require(_bpt <= 10000, "err TaxToken.sol _bpt > 10000");
        require(!taxesRemoved, "err TaxToken.sol taxation has been removed");
        basisPointsTax[_taxType] = _bpt;
    }

    /// @dev An input is required here for sanity-check, given importance of this function call (and irreversible nature).
    /// @param _key This value MUST equal 42 for function to execute.
    function permanentlyRemoveTaxes(uint _key) public onlyOwner {
        require(_key == 42, "err TaxToken.sol _key != 42");
        basisPointsTax[0] = 0;
        basisPointsTax[1] = 0;
        basisPointsTax[2] = 0;
        taxesRemoved = true;
    }


    // ~ Admin ~

    function transferOwnership(address _owner) public onlyOwner {
        owner = _owner;
    }

    function setTreasury(address _treasury) public onlyOwner {
        require(!treasurySet);
        treasury = _treasury;
        treasurySet = true;
    }

    function updateMaxTxAmount(uint256 _maxTxAmount) public onlyOwner {
        maxTxAmount = (_maxTxAmount * 10**18 );
    }
    
    function updateMaxWalletSize(uint256 _maxWalletSize) public onlyOwner {
        maxWalletSize = (_maxWalletSize * 10**18 );
    }

    function modifyWhitelist(address _wallet, bool _whitelist) public onlyOwner {
        whitelist[_wallet] = _whitelist;
    }

    function modifyBlacklist(address _wallet, bool _blacklist) public onlyOwner {
        isBlacklisted[_wallet] = _blacklist;
    }
    
}
