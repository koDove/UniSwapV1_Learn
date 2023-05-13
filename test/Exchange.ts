import { ethers } from "hardhat"
import { expect } from "chai";

import { Exchange } from "../typechain-types/contracts/Exchange"
import { Token } from "../typechain-types/contracts/Token";
import { BigNumber } from "ethers";

const toWei = (value: number) => ethers.utils.parseEther(value.toString());
const toEther = (value: BigNumber) => ethers.utils.formatEther(value);
const getBalance = ethers.provider.getBalance;

describe("Exchange", () => {
    let owner: any;
    let user: any;
    let exchange: Exchange;
    let token: Token;

    beforeEach(async () => {

        //기본적으로 10,000개의 Ether를 가지고 있음.
        [owner, user] = await ethers.getSigners();
        const TokenFactory = await ethers.getContractFactory("Token");
        token = await TokenFactory.deploy("GrayToken", "GRAY", toWei(1000000));
        await token.deployed();

        const ExchangeFactory = await ethers.getContractFactory("Exchange");
        exchange = await ExchangeFactory.deploy(token.address);
        await exchange.deployed();
    });


    describe("addLiquidity", async () => {
        it("add liquidity", async () => {
            await token.approve(exchange.address, toWei(500));
            await exchange.addLiquidity(toWei(500), { value: toWei(1000) });

            expect(await getBalance(exchange.address)).to.equal(toWei(1000));//유동성 풀의 이더 조회
            expect(await token.balanceOf(exchange.address)).to.equal(toWei(500));//유동성 풀의 토큰 조회

            //expect(await token.balanceOf(user.address)).to.equal(toWei(1)); //사용자 토큰 조회?
            //expect(await getBalance(user.address)).to.equal(toWei(9999)); //사용자 이더 조회?

            await token.approve(exchange.address, toWei(100));
            await exchange.addLiquidity(toWei(100), { value: toWei(200) });

            expect(await getBalance(exchange.address)).to.equal(toWei(1200));//유동성 풀의 이더 조회
            expect(await token.balanceOf(exchange.address)).to.equal(toWei(600));//유동성 풀의 토큰 조회

            await exchange.removeLiquidity(toWei(600));
            expect(await getBalance(exchange.address)).to.equal(toWei(600));//유동성 풀의 이더 조회
            expect(await token.balanceOf(exchange.address)).to.equal(toWei(300));//유동성 풀의 토큰 조회
        });
    });

    /*describe("removeLiquidity", async () => {
        it("remove liquidity", async () => {
            await exchange.removeLiquidity(toWei(600));
            expect(await getBalance(exchange.address)).to.equal(toWei(600));//유동성 풀의 이더 조회
            expect(await token.balanceOf(exchange.address)).to.equal(toWei(300));//유동성 풀의 토큰 조회
        });
    });*/

    describe("swapWithFee", async () => {
        it("correct swapWithFee", async () => {
            await token.approve(exchange.address, toWei(50));
            
            // 유동성 공급 ETH 50, GRAY 50
            await exchange.addLiquidity(toWei(50), {value: toWei(50)});

            // 유저가 ETH 30개를 스왑(최소 18 지정), GRAY 18632371392722710163 반환
            await exchange.connect(user).ethToTokenSwap(toWei(18), {value: toWei(30)});

            expect(toEther(await token.balanceOf(user.address)).toString()).to.equal("18.632371392722710163");

            await exchange.tokenBalance();
            await exchange.removeLiquidity(toWei(50)); 
            //expect(toEther(await exchange.balanceOf(owner.address)).toString()).to.equal("31.367628607277289837")
            //expect(toEther(await token.balanceOf(owner.address)).toString()).to.equal("18.632371392722710163");

        });
    });

    describe("tokenToTokenSwap", async () => {
        it("correct tokenToTokenSwap", async () => {
            [owner, user] = await ethers.getSigners();

            const FactoryFactory = await ethers.getContractFactory("Factory");
            const factory = await FactoryFactory.deploy();
            await factory.deployed();

            //2개의 토큰을 발행한다.
            const TokenFactory = await ethers.getContractFactory("Token");
            const token = await TokenFactory.deploy("DoveToken", "DOVE", toWei(1020));
            await token.deployed();

            const TokenFactory2 = await ethers.getContractFactory("Token");
            const token2 = await TokenFactory2.deploy("FastToken", "FAST", toWei(1000));
            await token2.deployed();

            //발행한 토큰 주소를 인자로 넘긴다. createExchange에서는 받은 토큰 주소로 자동으로 Exchange 컨트랙트를 생성한다.
            //이렇게 생성된 Exchange는 호출자가 Factory CA로 설정된다. 즉 Factory Contract가 이와 같은 방법으로 Exchange를 관리하게 된다.
            const exchangeAddress = await factory.callStatic.createExchange(token.address);
            await factory.createExchange(token.address);

            const exchangeAddress2 = await factory.callStatic.createExchange(token2.address);
            await factory.createExchange(token2.address);

            await token.approve(exchangeAddress, toWei(1000));
            await token2.approve(exchangeAddress2, toWei(1000));

            const ExchangeFactory = await ethers.getContractFactory("Exchange");
            await ExchangeFactory.attach(exchangeAddress).addLiquidity(toWei(1000), {value: toWei(1000)})
            await ExchangeFactory.attach(exchangeAddress2).addLiquidity(toWei(1000), {value: toWei(1000)})

            // 유동성 공급을 위해 approve 한 1000개를 다 썼으니 스왑을 위해 10개 다시 approve
            await token.approve(exchangeAddress, toWei(10));
            await ExchangeFactory.attach(exchangeAddress).tokenToTokenSwap(toWei(10), toWei(8), toWei(8), token2.address);

            console.log(toEther(await token2.balanceOf(owner.address)));
            console.log(toEther(await token2.balanceOf(exchangeAddress)));
        });
    }); 

}) 