const { expect } = require("chai");
import { BigNumber, Signer } from "ethers";
const usdcAbi = require("../../../abis/usdcAbi.json");
const comptrollerAbi = require("../../../abis/comptroller.json");
import hre, { upgrades } from "hardhat";
const aaveIncentiveContractAbi = require("../../../abis/aaveIncentiveContract.json");

const zero = BigNumber.from("0");
const one = BigNumber.from("1000000000000000000");
const maxValue = BigNumber.from(
    "115792089237316195423570985008687907853269984665640564039457584007913129639935"
);

import {
    CompoundStrategy,
    Stanley,
    IvToken,
    ERC20,
    IAaveIncentivesController,
    MockStrategy,
} from "../../../types";

// // Mainnet Fork and test case for mainnet with hardhat network by impersonate account from mainnet
// work for blockNumber: 14222087,
describe("Deposit -> deployed Contract on Mainnet fork", function () {
    let accounts: Signer[];
    let accountToImpersonate: string;
    let usdcAddress: string;
    let usdcContract: ERC20;
    let aaveStrategyContract_Instance: MockStrategy;
    let signer: Signer;
    let cUsdcAddress: string;
    let COMP: string;
    let compContract: ERC20;
    let cTokenContract: ERC20;
    let ComptrollerAddress: string;
    let compTrollerContract: any;
    let compoundStrategyContract_Instance: CompoundStrategy;
    let ivToken: IvToken;
    let stanley: Stanley;

    if (process.env.FORK_ENABLED != "true") {
        return;
    }

    before(async () => {
        accounts = await hre.ethers.getSigners();

        //  ********************************************************************************************
        //  **************                     GENERAL                                    **************
        //  ********************************************************************************************

        accountToImpersonate = "0xa191e578a6736167326d05c119ce0c90849e84b7"; // Usdc rich address
        usdcAddress = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"; // usdc

        await hre.network.provider.send("hardhat_setBalance", [
            accountToImpersonate,
            "0x100000000000000000000",
        ]);

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [accountToImpersonate],
        });

        signer = await hre.ethers.provider.getSigner(accountToImpersonate);
        usdcContract = new hre.ethers.Contract(usdcAddress, usdcAbi, signer) as ERC20;
        const impersonateBalanceBefore = await usdcContract.balanceOf(accountToImpersonate);
        await usdcContract.transfer(await accounts[0].getAddress(), impersonateBalanceBefore);
        signer = await hre.ethers.provider.getSigner(await accounts[0].getAddress());
        usdcContract = new hre.ethers.Contract(usdcAddress, usdcAbi, signer) as ERC20;

        //  ********************************************************************************************
        //  **************                         AAVE                                   **************
        //  *******************************************************************************************

        // we mock aave bacoude we want compand APR > aave APR
        const AaveStrategy = await hre.ethers.getContractFactory("MockStrategy");
        aaveStrategyContract_Instance = (await AaveStrategy.deploy()) as MockStrategy;

        await aaveStrategyContract_Instance.setShareToken(usdcAddress);
        await aaveStrategyContract_Instance.setAsset(usdcAddress);

        //  ********************************************************************************************
        //  **************                       COMPOUND                                 **************
        //  ********************************************************************************************

        cUsdcAddress = "0x39AA39c021dfbaE8faC545936693aC917d5E7563";
        COMP = "0xc00e94Cb662C3520282E6f5717214004A7f26888";
        ComptrollerAddress = "0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B";

        signer = await hre.ethers.provider.getSigner(accountToImpersonate);
        compContract = new hre.ethers.Contract(COMP, usdcAbi, signer) as ERC20;
        cTokenContract = new hre.ethers.Contract(cUsdcAddress, usdcAbi, signer) as ERC20;
        signer = await hre.ethers.provider.getSigner(await accounts[0].getAddress());

        const compoundStrategyContract = await hre.ethers.getContractFactory(
            "CompoundStrategy",
            signer
        );

        compoundStrategyContract_Instance = (await upgrades.deployProxy(compoundStrategyContract, [
            usdcAddress,
            cUsdcAddress,
            ComptrollerAddress,
            COMP,
        ])) as CompoundStrategy;

        compTrollerContract = new hre.ethers.Contract(ComptrollerAddress, comptrollerAbi, signer);

        //  ********************************************************************************************
        //  **************                        IvToken                                 **************
        //  ********************************************************************************************

        const tokenFactoryIvToken = await hre.ethers.getContractFactory("IvToken", signer);
        ivToken = (await tokenFactoryIvToken.deploy("IvToken", "IVT", usdcAddress)) as IvToken;

        //  ********************************************************************************************
        //  **************                       Stanley                                **************
        //  ********************************************************************************************
        const StanleyFactory = await hre.ethers.getContractFactory("Stanley", signer);

        stanley = (await await upgrades.deployProxy(StanleyFactory, [
            usdcAddress,
            ivToken.address,
            aaveStrategyContract_Instance.address,
            compoundStrategyContract_Instance.address,
        ])) as Stanley;

        await stanley.setMilton(await signer.getAddress());
        await compoundStrategyContract_Instance.setStanley(stanley.address);
        await compoundStrategyContract_Instance.setTreasury(await signer.getAddress());

        await usdcContract.approve(await signer.getAddress(), maxValue);
        await usdcContract.approve(stanley.address, maxValue);
        await ivToken.setStanley(stanley.address);
    });

    it("Shoiuld compand APR > aave APR ", async () => {
        // when
        const aaveApy = await aaveStrategyContract_Instance.getApr();
        const compoundApy = await compoundStrategyContract_Instance.getApr();
        // then
        expect(compoundApy.gt(aaveApy)).to.be.true;
    });

    it("Should accept deposit and transfer tokens into COMPOUND", async () => {
        //given
        const depositAmound = one.mul(10);
        const userAddress = await signer.getAddress();
        const userIvTokenBefore = await ivToken.balanceOf(userAddress);
        const compoundStrategyBalanceBefore = await compoundStrategyContract_Instance.balanceOf();

        expect(userIvTokenBefore, "userIvTokenBefore = 0").to.be.equal(zero);
        expect(compoundStrategyBalanceBefore, "compoundStrategyBalanceBefore = 0").to.be.equal(
            zero
        );

        //When
        await stanley.connect(signer).deposit(depositAmound);

        //Then
        const userIvTokenAfter = await ivToken.balanceOf(userAddress);
        const compoundStrategyBalanceAfter = await compoundStrategyContract_Instance.balanceOf();
        const userUsdcBalanceAfter = await usdcContract.balanceOf(userAddress);
        const strategyCTokenContractAfter = await cTokenContract.balanceOf(
            compoundStrategyContract_Instance.address
        );

        expect(userIvTokenAfter, "userIvTokenAfter = depositAmound").to.be.equal(depositAmound);
        expect(
            compoundStrategyBalanceAfter.gt(BigNumber.from("9999999999000000000")),
            "compoundStrategyBalanceAfter > 9999999999000000000"
        ).to.be.true;
        expect(userUsdcBalanceAfter, "userUsdcBalanceAfter = 227357362977886").to.be.equal(
            BigNumber.from("227357362977886")
        );
        expect(
            strategyCTokenContractAfter.gt(BigNumber.from("44438800000")),
            "strategyATokenContractAfter > 44438800000"
        ).to.be.true;
    });

    it("Should accept deposit twice and transfer tokens into COMPOUND", async () => {
        //given
        const depositAmound = one.mul(10);
        const userAddress = await signer.getAddress();
        const userIvTokenBefore = await ivToken.balanceOf(userAddress);
        const compoundStrategyBalanceBefore = await compoundStrategyContract_Instance.balanceOf();

        expect(userIvTokenBefore, "userIvTokenBefore = depositAmound").to.be.equal(depositAmound);
        expect(
            compoundStrategyBalanceBefore.gt(BigNumber.from("9999999999000000000")),
            "compoundStrategyBalanceBefore = 9999999999000000000"
        ).to.be.true;

        //When
        await stanley.connect(signer).deposit(depositAmound);
        await stanley.connect(signer).deposit(depositAmound);
        //Then
        const userIvTokenAfter = await ivToken.balanceOf(userAddress);
        const compoundStrategyBalanceAfter = await compoundStrategyContract_Instance.balanceOf();
        const userUsdcBalanceAfter = await usdcContract.balanceOf(userAddress);
        const strategyCTokenContractAfter = await cTokenContract.balanceOf(
            compoundStrategyContract_Instance.address
        );

        expect(
            userIvTokenAfter.gt(BigNumber.from("29999999950000000000")),
            "ivToken > 29999999950000000000"
        ).to.be.true;
        expect(
            compoundStrategyBalanceAfter.gt(BigNumber.from("30000000000000000000")),
            "aaveStrategyBalanceAfter > 30 * 10^18"
        ).to.be.true;
        expect(userUsdcBalanceAfter, "userUsdcBalanceAfter = 227357342977886").to.be.equal(
            BigNumber.from("227357342977886")
        );
        expect(
            strategyCTokenContractAfter.gte(BigNumber.from("133316000000")),
            "strategyCTokenContractAfter > 133316000000"
        ).to.be.true;
    });

    it("Should withdraw 10000000000000000000 from COMPOUND", async () => {
        //given
        const withdrawAmmond = one.mul(10);
        const userAddress = await signer.getAddress();
        const userIvTokenBefore = await ivToken.balanceOf(userAddress);
        const compoundStrategyBalanceBefore = await compoundStrategyContract_Instance.balanceOf();

        expect(
            userIvTokenBefore.gt(BigNumber.from("29999999950000000000")),
            "userIvTokenBefore = 29999999950000000000"
        ).to.be.true;
        expect(
            compoundStrategyBalanceBefore.gt(BigNumber.from("30000000000000000000")),
            "compoundStrategyBalanceBefore > 30 * 10^18"
        ).to.be.true;

        //when
        await stanley.withdraw(withdrawAmmond);
        //then
        const userIvTokenAfter = await ivToken.balanceOf(userAddress);
        const compoundStrategyBalanceAfter = await compoundStrategyContract_Instance.balanceOf();
        const userUsdcBalanceAfter = await usdcContract.balanceOf(userAddress);
        const strategyCTokenContractAfter = await cTokenContract.balanceOf(
            compoundStrategyContract_Instance.address
        );

        expect(
            userIvTokenAfter.gt(BigNumber.from("19999999950000000000")),
            "ivToken = 19999999950000000000"
        ).to.be.true;
        expect(
            compoundStrategyBalanceAfter.gt(BigNumber.from("20000000000000000000")),
            "compoundStrategyBalanceAfter > 20 * 10 ^18"
        ).to.be.true;
        expect(
            compoundStrategyBalanceAfter.lt(BigNumber.from("30000000000000000000")),
            "compoundStrategyBalanceAfter < 30 * 10 ^18"
        ).to.be.true;
        expect(
            userUsdcBalanceAfter.gt(BigNumber.from("227357352000000")),
            "userUsdcBalanceAfter > 227357352000000"
        ).to.be.true;
        expect(
            strategyCTokenContractAfter.gt(BigNumber.from("88877600000")),
            "strategyCTokenContractAfter >  88877600000"
        ).to.be.true;
    });

    it("Should withdraw all user assset from COMPOUND", async () => {
        //given
        const userAddress = await signer.getAddress();
        const userIvTokenBefore = await ivToken.balanceOf(userAddress);
        const compoundStrategyBalanceBefore = await compoundStrategyContract_Instance.balanceOf();
        const userUsdcBalanceBefore = await usdcContract.balanceOf(userAddress);

        expect(
            userIvTokenBefore.gt(BigNumber.from("19999999950000000000")),
            "userIvTokenBefore > 19999999950000000000"
        ).to.be.true;
        expect(
            compoundStrategyBalanceBefore.gt(BigNumber.from("20000000000000000000")),
            "compomudStrategyBalanceBefore > 20000000000000000000"
        ).to.be.true;

        //when
        await stanley.withdraw(compoundStrategyBalanceBefore);

        //then
        const userIvTokenAfter = await ivToken.balanceOf(userAddress);
        const compoundStrategyBalanceAfter = await compoundStrategyContract_Instance.balanceOf();
        const userUsdcBalanceAfter = await usdcContract.balanceOf(userAddress);
        const strategyCTokenContractAfterWithdraw = await cTokenContract.balanceOf(
            aaveStrategyContract_Instance.address
        );

        expect(userIvTokenAfter.lt(BigNumber.from("1000")), "ivToken < 1000").to.be.true;
        expect(compoundStrategyBalanceAfter, "compoundStrategyBalanceAfter = 0").to.be.equal(
            BigNumber.from("334842407899")
        );
        expect(
            userUsdcBalanceAfter.gt(userUsdcBalanceBefore),
            "userUsdcBalanceAfter > userUsdcBalanceBefore"
        ).to.be.true;
        expect(
            strategyCTokenContractAfterWithdraw,
            "strategyCTokenContractAfterWithdraw = 0"
        ).to.be.equal(zero);
    });
    it("Should Clame from COMPOUND", async () => {
        //given
        const treasurAddres = await accounts[0].getAddress();
        const timestamp = Math.floor(Date.now() / 1000) + 864000 * 2;
        await hre.network.provider.send("evm_setNextBlockTimestamp", [timestamp]);
        await hre.network.provider.send("evm_mine");

        const compoundBalanceBefore = await compContract.balanceOf(treasurAddres);
        expect(compoundBalanceBefore, "Cliamed Compound Balance Before = 0").to.be.equal(zero);

        // when
        await compoundStrategyContract_Instance.doClaim();

        // then
        const userOneBalance = await compContract.balanceOf(treasurAddres);
        expect(
            userOneBalance.gt(BigNumber.from("1821261900")),
            "Cliamed compound Balance = 1821261900"
        ).to.be.true;
    });
});
