import express, { Express, NextFunction, Request, Response, Router } from "express";
import dotenv from "dotenv";
import { ethers } from "hardhat";

import { DEX, ERC20 } from "../typechain";
import { BigNumber } from "ethers";

dotenv.config();

const app: Express = express();
const port: string = process.env.PORT !== undefined ? process.env.PORT: "8000";
const router: Router = express.Router();

async function handleError(res: Response, fn: () => Promise<void>) {
  try {
    await fn();
  } catch(error) {
    console.log(error);
    res.status(500).send("Internal server error");
  }
}

let dex: DEX;

router.get('/tokens/', async (req: Request, res: Response) => {
  await handleError(res, async() => {
    res.send(await dex.supportedTokens());
  });
});

router.get('/tokens/:tokenAddress', async (req: Request, res: Response) => {
  await handleError(res, async() => {
    const token: ERC20 = await ethers.getContractAt("ERC20", req.params.tokenAddress);
    let [
      tokenName,
      tokenSymbol, 
      tokenDecimals, 
      totalSupply
    ]: Array<string|number|BigNumber> = await Promise.all([
      token.name(),
      token.symbol(),
      token.decimals(),
      token.totalSupply()
    ]);

    res.send({
      name: tokenName,
      symbol: tokenSymbol,
      decimals: tokenDecimals,
      totalSupply: totalSupply.toString()
    });
  });
});

router.get('/dex/rates/:tokenAddress', async (req: Request, res: Response) => {
  await handleError(res, async() => {
    let [
      buyRate,
      sellRate
    ]: Array<BigNumber> = await Promise.all([
      dex.buyRate(req.params.tokenAddress),
      dex.sellRate(req.params.tokenAddress)
    ]);

    res.send({
      buyRate: buyRate.toString(),
      sellRate: sellRate.toString(),
    });
  });
});

router.get('/dex/max_exchange/eth', async (req: Request, res: Response) => {
  await handleError(res, async() => {
    let amount: BigNumber = await dex.maxExchangeETH();
    res.send(amount.toString());
  });
});

router.get('/dex/max_exchange/:tokenAddress', async (req: Request, res: Response) => {
  await handleError(res, async() => {
    let amount: BigNumber = await dex.maxExchangeToken(req.params.tokenAddress);
    res.send(amount.toString());
  });
});

router.get('/dex/trades/:tokenAddress', async (req: Request, res: Response) => {
  await handleError(res, async() => {
    let [buys, sales]: Array<BigNumber> = await Promise.all([
      dex.buysAmount(req.params.tokenAddress),
      dex.salesAmount(req.params.tokenAddress),
    ]);
    res.send({buys: buys.toString(), sales: sales.toString()});
  });
});

app.use('/', router);

app.listen(port, async () => {
  console.log(`[server]: Server is running at https://localhost:${port}`);
  dex = await ethers.getContract("DEX");
  console.log(`[server]: Dex address: ${dex.address}`);
});