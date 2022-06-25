# Description
There are a decentralized exchange contract to buy and sell ERC20 tokens and simple API to get contract data.<br><br>
Contract's main features:
* DEX deploys new ERC20 tokens.
* DEX sets up the exchange rates.
* DEX allows users to buy tokens for ETH.
* DEX allows users to sell tokens for ETH.
* DEX sends percent of received ETH to the contract owner.<br><br>

API endpoints:
* `/tokens/` returns the list of all supported tokens.
* `/tokens/:tokenAddress` returns basic token's info: name, symbol, decimals, total supply.
* `/dex/rates/:tokenAddress` returns buy and sell rates for the token.
* `/dex/max_exchange/eth` returns the maximum ETH amount to be exchanged.
* `/dex/max_exchange/:tokenAddress` returns the maximum tokens amount to be exchanged.
* `/dex/trades/:tokenAddress` returns amount of token's buys and sales.
<br><br>

## Launch instructions
To run this project you need to have Node.js and npm installed. Please check [installation instructions](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm) if needed.
<br><br>
Install project's dependencies:
```shell
npm install --save-dev
```

When installation process is finished, create `.env` file from `.env.example` and set `API_URL`, `PRIVATE_KEY` and `ETHERSCAN_API_KEY` variables there to be able to deploy the contracts to Rinkeby testnet.

Start local node with deployed DEX and ERC20 token contracts:
```shell
npx hardhat node
```

Start API server and connect to the local node:
```shell
npx hardhat --network localhost run api/app.ts
```

Run tests:
```shell
npx hardhat test
```

Test coverage:
```shell
npx hardhat coverage
```

Deploy contracts to Rinkeby testnet:
```shell
npx hardhat --network rinkeby deploy 
```

Verify contracts on Rinkeby testnet:
```shell
npx hardhat --network rinkeby etherscan-verify
```
Start API server and connect to the rinkeby node:
```shell
npx hardhat --network rinkeby run api/app.ts
```