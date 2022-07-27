## Introduction

In this repo you will find an overworked and fully optimized take on an ERC20 token. The TaxToken and Treasury focus on optimizing gas, fully customizable royalty distributions, and blacklist/whitelist functionality.

- [TaxToken](./src/TaxToken.sol) - This contract is the main token contract which follows the ERC20 standard. This contract is for handling the deployment of the token, manages transactions, whitelisting, and blacklisting. Also features the following ERC20 extensions:
  - ERC20Pausable
  - ERC20Burnable
  - ERC20Mintable
  
- [Treasury](./src/Treasury.sol) - This smart contract is the Treasury contract that works alongside the TaxToken. The TaxToken will take a royalty on transactions and send those royalties to this contract for management and distribution. The Treasury contract allows royalties to be collected for 3 taxTypes: buys, sells, and sends. Each taxType can have a customized distribution to a number of wallets. When royalties are distributed, royalties can be distributed as TaxToken, stablecoin, or WETH.

**NOTE:** This framework is [dapptools](https://github.com/dapphub/dapptools), a suite of Ethereum focused CLI tools following the Unix design philosophy, favoring composability, configurability and extensibility. If you do not have dapptools installed, please locate the dapptools github repo and follow the installation instructions.

[![Homepage](https://img.shields.io/badge/Elevate%20Software-Homepage-brightgreen)](https://www.elevatesoftware.io/)