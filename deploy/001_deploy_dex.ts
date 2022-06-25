import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  const divisionAccuracy: string = process.env.DIVISION_ACCURACY !== undefined ? process.env.DIVISION_ACCURACY: "100000";
  const ownerFee: string = process.env.OWNER_FEE !== undefined ? process.env.OWNER_FEE : "500000000000000000"; // 50%

  console.log(`Division accuracy: ${divisionAccuracy}, ownerFee: ${ownerFee}`);
  
  // deploy DEX contract
  await deploy("DEX", {
    contract: "DEX",
    from: deployer,
    args: [divisionAccuracy, ownerFee],
    log: true,
    autoMine: true, // speed up deployment on local network (ganache, hardhat), no effect on live networks
  });
};

export default func;
func.tags = ["DEX"];