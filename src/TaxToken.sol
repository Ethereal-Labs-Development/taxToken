//SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import { ITreasury } from "./interfaces/ERC20.sol";

contract TaxToken {

    //
 
    // Table to map addresses
    // to their balance
    mapping(address => uint256) balances;
 
    // Mapping owner address to
    // those who are allowed to
    // use the contract
    mapping(address => mapping(address => uint256)) allowed;

    // Any transfer that involves a whitelisted address, will not incur a tax.
    mapping(address => bool) whitelist;
    mapping(address => uint) senderTaxType;
    mapping(address => uint) receiverTaxType;

    // Mapping between taxType and basisPoints (taxed).
    mapping(uint => uint) basisPointsTax;

    uint256 _totalSupply;

    // owner address - adding public generates a getter for the regular callers
    address public owner;
    address public adminWallet;
    address public treasury;
    bool public treasurySet;

    //Only accessable through getters we set, want to keep our enpoints consistent with everyone else
    string private _name;
    string private _symbol;
    uint8 private _decimals;
 
    modifier onlyOwner {
       //_; acts as a "continue after this" specifically for modifiers
       require(msg.sender == owner, "ERR: TaxToken.sol, onlyOwner()");
       _;
    }

    // TEMPORARY (REMOVE LATER)
    event LogUint(string s, uint u);
    event LogAddy(string s, address a);

    // Triggered whenever
    // approve(address _spender, uint256 _value)
    // is called.
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
 
    // Event triggered when
    // tokens are transferred.
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event TransferTax(address indexed _from, address indexed _to, uint256 _value, uint256 _taxType);

    //Instead of hard coding, you can pass things like supply, sumbol, ect through the constructor
    //upon deployment to reduce LOC. *Limit of 12 inpus per function
    constructor(
        uint totalSupplyInput, 
        string memory nameInput, 
        string memory symbolInput, 
        uint8 decimalsInput,
        address adminWalletInput
    ) {
        owner = msg.sender;
        balances[msg.sender] = totalSupplyInput;   // Initial liquidity (allocated to Owner). 
        _totalSupply = totalSupplyInput;
        _name = nameInput;
        _symbol = symbolInput;
        _decimals = decimalsInput;
        adminWallet = adminWalletInput;
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
    }

    function transferOwnership(address _owner) public onlyOwner {
        //_ for parameter input for functions, and non for variables
        owner = _owner;
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
    function transfer(address _to, uint256 _amount) public returns (bool success)
    {

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

                if (receiverTaxType[msg.sender] != 0) {
                    _taxType = receiverTaxType[msg.sender];
                }

                // Calculate taxAmt and sendAmtS
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
 
    function transferFrom(address _from, address _to, uint256 _amount) public returns (bool success) {
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
