import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber, ContractReceipt, ContractTransaction, Event } from "ethers";
import { ethers, deployments } from "hardhat";

import { DEX, ERC20, TestSeller, TestSeller__factory } from "../typechain";

describe("DEX", function () {
  const ttdConfig = {
    buyRate: 10000,
    sellRate: 5000
  };

  const tokenConfig = {
    name: process.env.TOKEN_NAME !== undefined ? process.env.TOKEN_NAME as string : "TestTokenDex",
    symbol: process.env.TOKEN_SYMBOL !== undefined ? process.env.TOKEN_SYMBOL as string: "TTD",
    decimals: process.env.TOKEN_DECIMALS !== undefined ? process.env.TOKEN_DECIMALS as string : "2",
    initialSupply: process.env.INITIAL_SUPPLY !== undefined ? process.env.INITIAL_SUPPLY as string : "500000000000000"
  };

  const divisionAccuracy: BigNumber = process.env.DIVISION_ACCURACY !== undefined ? BigNumber.from(process.env.DIVISION_ACCURACY): BigNumber.from(1e5);
  const ownerFee: BigNumber = process.env.OWNER_FEE !== undefined ? BigNumber.from(process.env.OWNER_FEE) : BigNumber.from("500000000000000000"); // 50%

  let dex: DEX;
  let testSellerFactory: TestSeller__factory;
  let testSeller: TestSeller;
  let ttd: ERC20;
  let ttd2: ERC20;
  let deployer: SignerWithAddress;
  let user: SignerWithAddress;
  
  function getTokenAddress(rc: ContractReceipt): string {
    if (rc.events) {
        const event: Event | undefined = rc.events.find(event => event.event === 'NewToken');
        if (event?.args) {
          return event.args["token"];
        } else {
          expect.fail("No event args");
        }
      } else {
        expect.fail("No events");
      }
  };

  function accurateDiv(dividend: BigNumber, divider: BigNumber): BigNumber {
    return dividend.mul(divisionAccuracy).div(divider).div(divisionAccuracy);
  }

  before(async () => {
    deployer = await ethers.getNamedSigner("deployer");
    [ user ] = await ethers.getUnnamedSigners();

    await deployments.fixture();

    dex = await ethers.getContract("DEX", deployer);
    ttd = await ethers.getContractAt("ERC20", (await dex.supportedTokens())[0]);
  });

  it("Doesn't deploy token by non-owner", async function () {
    await expect(dex.connect(user).createToken(tokenConfig)).to.be.revertedWith("NotOwner()");
  });

  it("Deploys token", async function () {
    const tx: ContractTransaction = await dex.createToken(tokenConfig);
    const rc: ContractReceipt = await tx.wait();
    const tokenAddress: string = getTokenAddress(rc);
    ttd2 = await ethers.getContractAt("ERC20", tokenAddress);
  });

  it("Sets rates up", async function () {
    expect(await dex.buyRate(ttd.address)).to.be.equal(0);
    expect(await dex.sellRate(ttd.address)).to.be.equal(0);

    await expect(dex.setupRates(ttd.address, ttdConfig.buyRate, ttdConfig.sellRate))
      .to.emit(dex, "RatesUpdate")
      .withArgs(ttd.address, ttdConfig.buyRate, ttdConfig.sellRate);

    expect(await dex.buyRate(ttd.address)).to.be.equal(ttdConfig.buyRate);
    expect(await dex.sellRate(ttd.address)).to.be.equal(ttdConfig.sellRate);
  });

  it("Returns all supported tokens", async function () {
    expect(await dex.supportedTokens()).to.be.deep.equal([ttd.address, ttd2.address]);
  });

  it("Doesn't sell non-existent tokens", async function () {
    const amountToSend: BigNumber = ethers.utils.parseEther("1.0");
    const userETHBalance: BigNumber = await ethers.provider.getBalance(user.address);
    
    await expect(dex.connect(user)
      .buyTokens(ethers.constants.AddressZero, {value: amountToSend}))
      .to.be.revertedWith(`InvalidToken("${ethers.constants.AddressZero}")`);

    expect(await ethers.provider.getBalance(user.address))
      .to.be.gt(userETHBalance.sub(amountToSend));
  });

  it("Doesn't sell tokens more than their supply", async function () {
    const tokensAmountTotal: BigNumber = await dex.maxExchangeToken(ttd.address);
    const buyRate: BigNumber = await dex.buyRate(ttd.address);
    const amountToSend: BigNumber = buyRate.mul(tokensAmountTotal).mul(2);
    const tokensAmount: BigNumber = accurateDiv(amountToSend, buyRate);
    const userETHBalance: BigNumber = await ethers.provider.getBalance(user.address);
    
    await expect(dex.connect(user)
      .buyTokens(ttd.address, {value: amountToSend}))
      .to.be.revertedWith(`InvalidAmount(${tokensAmount})`);

    expect(await ethers.provider.getBalance(user.address))
      .to.be.gt(userETHBalance.sub(amountToSend));
  });

  it("Sells tokens to buyer", async function () {
    const amountToSend: BigNumber = ethers.utils.parseEther("1.0");
    const deployerETHBalance: BigNumber = await ethers.provider.getBalance(deployer.address);
    const userETHBalance: BigNumber = await ethers.provider.getBalance(user.address);
    const dexETHBalance: BigNumber = await ethers.provider.getBalance(dex.address);
    const tokensAmount: BigNumber = accurateDiv(amountToSend, await dex.buyRate(ttd.address));
    const deployerFee: BigNumber = amountToSend.mul(ownerFee).div(BigInt(1e18));
    
    expect(await ttd.balanceOf(dex.address)).to.be.equal(tokenConfig.initialSupply);
    expect(await ttd.balanceOf(user.address)).to.be.equal(0);
    

    await expect(dex.connect(user)
      .buyTokens(ttd.address, {value: amountToSend}))
      .to.emit(dex, "Buy")
      .withArgs(user.address, ttd.address, tokensAmount);

    expect(await ethers.provider.getBalance(deployer.address))
      .to.be.equal(deployerETHBalance.add(deployerFee));
    expect(await ethers.provider.getBalance(dex.address))
      .to.be.equal(dexETHBalance.add(deployerFee));
    expect(await ethers.provider.getBalance(user.address))
      .to.be.lt(userETHBalance.sub(amountToSend));

    expect(await ttd.balanceOf(user.address)).to.be.equal(tokensAmount);
    expect(await ttd.balanceOf(dex.address)).to.be.equal(BigNumber.from(tokenConfig.initialSupply).sub(tokensAmount));
  });

  it("Returns buys amount",async () => {
    expect(await dex.buysAmount(ttd.address)).to.be.equal(1);
  });

  it("Doesn't buy tokens for more than ETH supply", async function () {
    const ethAmountTotal: BigNumber = await dex.maxExchangeETH();
    const sellRate: BigNumber = await dex.sellRate(ttd.address);
    const amountToSell: BigNumber = ethAmountTotal.div(sellRate).mul(2);
    const ethAmount: BigNumber = amountToSell.mul(sellRate);
    const userTokenBalance: BigNumber = await await ttd.balanceOf(user.address);
    
    await expect(dex.connect(user)
      .sellTokens(ttd.address, amountToSell))
      .to.be.revertedWith(`InvalidAmount(${ethAmount})`);

      expect(await ttd.balanceOf(user.address))
      .to.be.equal(userTokenBalance);
  });
  
  it("Buys tokens from seller", async function () {
    const userETHBalance: BigNumber = await ethers.provider.getBalance(user.address);
    const dexETHBalance: BigNumber = await ethers.provider.getBalance(dex.address);
    const userTokensBalance: BigNumber = await ttd.balanceOf(user.address);
    const dexTokensBalance: BigNumber = await ttd.balanceOf(dex.address);
    const sellRate: BigNumber = await dex.sellRate(ttd.address);
    const ethAmount: BigNumber = userTokensBalance.mul(sellRate);

    await ttd.connect(user).approve(dex.address, userTokensBalance);

    await expect(dex.connect(user)
      .sellTokens(ttd.address, userTokensBalance))
      .to.emit(dex, "Sale")
      .withArgs(user.address, ttd.address, userTokensBalance);

    expect(await ttd.balanceOf(user.address)).to.be.equal(0);
    expect(await ttd.balanceOf(dex.address)).to.be.equal(dexTokensBalance.add(userTokensBalance));
    expect(await ethers.provider.getBalance(user.address)).to.be.gt(userETHBalance);
    expect(await ethers.provider.getBalance(dex.address)).to.be.equal(dexETHBalance.sub(ethAmount));
  });

  it("Returns sales amount",async () => {
    expect(await dex.salesAmount(ttd.address)).to.be.equal(1);
  });

  it("Doesn't buy tokens from address which can't receive ETH",async () => {
    const amountToSend: BigNumber = ethers.utils.parseEther("1.0");
    const sellRate: BigNumber = await dex.sellRate(ttd.address);
    const amountToReceive: BigNumber = (await dex.tokensAmountToBuy(ttd.address, amountToSend)).mul(sellRate);

    testSellerFactory = await ethers.getContractFactory("TestSeller");
    testSeller = await testSellerFactory.deploy(dex.address, ttd.address);
    await testSeller.deployed();

    await expect(testSeller.connect(user).buyAndSellTokens({value: amountToSend}))
      .to.be.revertedWith(`TransferFailed("${testSeller.address}", ${amountToReceive})`);
  });
});
