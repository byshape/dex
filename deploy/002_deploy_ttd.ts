import { ethers } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

import { DEX } from "../typechain";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const tokenConfig = {
    name: process.env.TOKEN_NAME !== undefined ? process.env.TOKEN_NAME as string : "TestTokenDex",
    symbol: process.env.TOKEN_SYMBOL !== undefined ? process.env.TOKEN_SYMBOL as string: "TTD",
    decimals: process.env.TOKEN_DECIMALS !== undefined ? process.env.TOKEN_DECIMALS as string : "2",
    initialSupply: process.env.INITIAL_SUPPLY !== undefined ? process.env.INITIAL_SUPPLY as string : "500000000000000"
  };

  // get deployed DEX and create ERC20 ttd token
  const dex = await ethers.getContract("DEX") as DEX;
  await dex.createToken(tokenConfig)
};

export default func;
func.tags = ["TTD"];
func.dependencies = ["DEX"];