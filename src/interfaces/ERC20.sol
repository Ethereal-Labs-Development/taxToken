// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

interface ITreasury {
    function updateTaxesAccrued(uint taxType, uint amt) external;
}

interface IERC20 {
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external;
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external;
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

struct Slot0 {
    // the current price
    uint160 sqrtPriceX96;
    // the current tick
    int24 tick;
    // the most-recently updated index of the observations array
    uint16 observationIndex;
    // the current maximum number of observations that are being stored
    uint16 observationCardinality;
    // the next maximum number of observations to store, triggered in observations.write
    uint16 observationCardinalityNext;
    // the current protocol fee as a percentage of the swap fee taken on withdrawal
    // represented as an integer denominator (1/x)%
    uint8 feeProtocol;
    // whether the pool is locked
    bool unlocked;
}

interface IUniPool {
    function slot0() external returns(Slot0 memory slot0);
    function liquidity() external returns(uint128 liquidity);
    function fee() external returns(uint24 fee);
    function token0() external returns(address token0);
    function token1() external returns(address token1);
    function tickSpacing() external returns(int24 tickSpacing);
    function tickBitmap(int16 i) external payable returns(uint256 o);
}


interface ILiquidityPoolV4 {

}

interface IDapperTri {
    function get_paid(
        address[3] memory _route, 
        uint8[3] memory _exchanges, 
        uint24[4] memory _poolFees, 
        address _borrow, 
        uint _borrowAmt
    ) external;
}

struct ExactInputSingleParams {
    address tokenIn;
    address tokenOut;
    uint24 fee;
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint160 sqrtPriceLimitX96;
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function getAmountsOut(
        uint amountIn, 
        address[] calldata path
    ) external view returns (uint[] memory amounts);
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

interface IUniswapQuoterV3 {
    function quoteExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
    ) external view returns (uint256 amountOut);
}

interface IUniswapRouterV3 {
    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);
}

// https://etherscan.io/address/0x2F9EC37d6CcFFf1caB21733BdaDEdE11c823cCB0#code
interface IBancorNetwork {
     function conversionPath(
         IERC20 _sourceToken, 
         IERC20 _targetToken
    ) external view returns (address[] memory);
    function convert(
        address[] memory path,
        uint256 sourceAmount,
        uint256 minReturn
    ) external payable returns (uint256);
    function convertByPath(
        address[] memory path,
        uint256 sourceAmount,
        uint256 minReturn,
        address payable beneficiary,
        address affiliate,
        uint256 affiliateFee
    ) external payable returns (uint256);
    function rateByPath(
        address[] memory path, 
        uint256 sourceAmount
    ) external view returns (uint256);
}

// https://etherscan.io/address/0x8301ae4fc9c624d1d396cbdaa1ed877821d7c511#code (ETH/CRV)
// https://etherscan.io/address/0xDC24316b9AE028F1497c275EB9192a3Ea0f67022#code (ETH/stETH)
interface ICRVMetaPool {
    // i = token_from
    // j = token_to
    // dx = token_from_change
    // min_dy = token_to_min_receive
    // function get_dy(int128 i, int128 j, uint256 dx) external view returns(uint256); 
    function get_dy(uint256 i, uint256 j, uint256 dx) external view returns(uint256); 
    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external payable returns(uint256); 
    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy, bool use_eth) external payable returns(uint256);
    function exchange_underlying(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external payable returns(uint256);
    function add_liquidity(uint256[] memory amounts_in, uint256 min_mint_amount) external payable returns(uint256);
    function remove_liquidity(uint256 amount, uint256[] memory min_amounts_out) external returns(uint256[] memory);
}

interface ICRV {
    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external payable; 
    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy, bool use_eth) external payable;
}

interface ICRV_PP_128_NP {
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
    function get_dy(int128 i, int128 j, uint256 dx) external view returns(uint256);
}
interface ICRV_PP_256_NP {
    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy, bool use_eth) external;
    function get_dy(uint256 i, uint256 j, uint256 dx) external view returns(uint256);
}
interface ICRV_PP_256_P {
    function exchange_underlying(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external payable returns(uint256);
    function get_dy(uint256 i, uint256 j, uint256 dx) external view returns(uint256);
}
interface ICRV_MP_256 {
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external payable returns(uint256);
    function exchange_underlying(int128 i, int128 j, uint256 dx, uint256 min_dy) external payable returns(uint256);
    function get_dy(int128 i, int128 j, uint256 dx) external view returns(uint256);
}

interface ICRVSBTC {
    // i = token_from
    // j = token_to
    // dx = token_from_change
    // min_dy = token_to_min_receive
    function get_dy(int128 i, int128 j, uint256 dx) external view returns(uint256); 
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external returns(uint256); 
    function add_liquidity(uint256[3] memory amounts_in, uint256 min_mint_amount) external;
    function remove_liquidity(uint256 amount, uint256[3] memory min_amounts_out) external;
    function remove_liquidity_one_coin(uint256 token_amount, int128 index, uint min_amount) external;
}

interface ICRVSBTC_CRV {
    // i = token_from
    // j = token_to
    // dx = token_from_change
    // min_dy = token_to_min_receive
    function get_dy(int128 i, int128 j, uint256 dx) external view returns(uint256); 
    // function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external returns(uint256);
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy, address _receiver) external; 
    function add_liquidity(uint256[3] memory amounts_in, uint256 min_mint_amount) external;
    function remove_liquidity(uint256 amount, uint256[3] memory min_amounts_out) external;
    function remove_liquidity_one_coin(uint256 token_amount, int128 index, uint min_amount) external;
}

// https://etherscan.io/address/0xd9e1ce17f2641f24ae83637ab66a2cca9c378b9f#code
interface ISushiRouter {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function getAmountsOut(
        uint amountIn, 
        address[] calldata path
    ) external view returns (uint[] memory amounts);
}

// https://etherscan.io/address/0x7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0#code
interface IWSTETH {
    function wrap(uint256 _stETHAmount) external returns (uint256);
    function unwrap(uint256 _wstETHAmount) external returns (uint256);
}

interface IVault {
    function flashLoan(
        IFlashLoanRecipient recipient,
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;
}

interface IFlashLoanRecipient {
    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external;
}

interface IWETH {
    function deposit() external payable;
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}