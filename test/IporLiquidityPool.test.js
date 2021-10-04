const testUtils = require("./TestUtils.js");
const {time, BN} = require("@openzeppelin/test-helpers");
const {ZERO} = require("./TestUtils");
const TestUtils = require("./TestUtils");
const MiltonConfiguration = artifacts.require('MiltonConfiguration');
const TestMilton = artifacts.require('TestMilton');
const MiltonStorage = artifacts.require('MiltonStorage');
const TestWarren = artifacts.require('TestWarren');
const WarrenStorage = artifacts.require('WarrenStorage');
const IporToken = artifacts.require('IporToken');
const DaiMockedToken = artifacts.require('DaiMockedToken');
const UsdtMockedToken = artifacts.require('UsdtMockedToken');
const UsdcMockedToken = artifacts.require('UsdcMockedToken');
const DerivativeLogic = artifacts.require('DerivativeLogic');
const SoapIndicatorLogic = artifacts.require('SoapIndicatorLogic');
const TotalSoapIndicatorLogic = artifacts.require('TotalSoapIndicatorLogic');
const IporAddressesManager = artifacts.require('IporAddressesManager');
const MiltonDevToolDataProvider = artifacts.require('MiltonDevToolDataProvider');
const IporLiquidityPool = artifacts.require('IporLiquidityPool');

contract('IporLiquidityPool', (accounts) => {

    const [admin, userOne, userTwo, userThree, liquidityProvider, _] = accounts;

    let milton = null;
    let miltonStorage = null;
    let derivativeLogic = null;
    let soapIndicatorLogic = null;
    let totalSoapIndicatorLogic = null;
    let tokenDai = null;
    let tokenUsdt = null;
    let tokenUsdc = null;
    let iporTokenUsdt = null;
    let iporTokenUsdc = null;
    let iporTokenDai = null;
    let warren = null;
    let warrenStorage = null;
    let miltonConfiguration = null;
    let iporAddressesManager = null;
    let miltonDevToolDataProvider = null;
    let iporLiquidityPool = null;

    before(async () => {
        derivativeLogic = await DerivativeLogic.deployed();
        soapIndicatorLogic = await SoapIndicatorLogic.deployed();
        totalSoapIndicatorLogic = await TotalSoapIndicatorLogic.deployed();
        miltonConfiguration = await MiltonConfiguration.deployed();
        iporAddressesManager = await IporAddressesManager.deployed();
        miltonDevToolDataProvider = await MiltonDevToolDataProvider.deployed();
        iporLiquidityPool = await IporLiquidityPool.deployed();

        //TODO: zrobic obsługę 6 miejsc po przecinku! - totalSupply6Decimals
        tokenUsdt = await UsdtMockedToken.new(testUtils.TOTAL_SUPPLY_6_DECIMALS, 6);
        tokenUsdc = await UsdcMockedToken.new(testUtils.TOTAL_SUPPLY_18_DECIMALS, 18);
        tokenDai = await DaiMockedToken.new(testUtils.TOTAL_SUPPLY_18_DECIMALS, 18);


        milton = await TestMilton.new();

        for (let i = 1; i < accounts.length - 2; i++) {
            //Milton has rights to spend money on behalf of user accounts[i]
            await tokenUsdt.approve(milton.address, testUtils.TOTAL_SUPPLY_6_DECIMALS, {from: accounts[i]});
            //TODO: zrobic obsługę 6 miejsc po przecinku! - totalSupply6Decimals
            await tokenUsdc.approve(milton.address, testUtils.TOTAL_SUPPLY_18_DECIMALS, {from: accounts[i]});
            await tokenDai.approve(milton.address, testUtils.TOTAL_SUPPLY_18_DECIMALS, {from: accounts[i]});
        }

        await iporAddressesManager.setAddress("MILTON_CONFIGURATION", await miltonConfiguration.address);
        await iporAddressesManager.setAddress("MILTON", milton.address);

        await iporAddressesManager.addAsset(tokenUsdt.address);
        await iporAddressesManager.addAsset(tokenUsdc.address);
        await iporAddressesManager.addAsset(tokenDai.address);

        await milton.initialize(iporAddressesManager.address);
        await iporLiquidityPool.initialize(iporAddressesManager.address);

    });

    beforeEach(async () => {
        miltonStorage = await MiltonStorage.new();
        await iporAddressesManager.setAddress("MILTON_STORAGE", miltonStorage.address);

        warrenStorage = await WarrenStorage.new();

        warren = await TestWarren.new(warrenStorage.address);
        await iporAddressesManager.setAddress("WARREN", warren.address);

        await warrenStorage.addUpdater(userOne);
        await warrenStorage.addUpdater(warren.address);

        await miltonStorage.initialize(iporAddressesManager.address);

        await miltonStorage.addAsset(tokenDai.address);
        await miltonStorage.addAsset(tokenUsdc.address);
        await miltonStorage.addAsset(tokenUsdt.address);

        iporTokenUsdt = await IporToken.new(tokenUsdt.address, 6, "IPOR USDT", "ipUSDT");
        iporTokenUsdt.initialize(iporAddressesManager.address);
        iporTokenUsdc = await IporToken.new(tokenUsdc.address, 18, "IPOR USDC", "ipUSDC");
        iporTokenUsdc.initialize(iporAddressesManager.address);
        iporTokenDai = await IporToken.new(tokenDai.address, 18, "IPOR DAI", "ipDAI");
        iporTokenDai.initialize(iporAddressesManager.address);

        await iporAddressesManager.setIporToken(tokenUsdt.address, iporTokenUsdt.address);
        await iporAddressesManager.setIporToken(tokenUsdc.address, iporTokenUsdc.address);
        await iporAddressesManager.setIporToken(tokenDai.address, iporTokenDai.address);

    });

    it('should calculate Exchange Rate when Liquidity Pool Balance and Ipor Token Total Supply is zero', async () => {
        //given
        let expectedExchangeRate = BigInt("1000000000000000000");
        //when
        let actualExchangeRate = BigInt(await iporLiquidityPool.calculateExchangeRate.call(tokenDai.address));

        //then
        assert(expectedExchangeRate === actualExchangeRate,
            `Incorrect exchange rate for DAI, actual:  ${actualExchangeRate},
            expected: ${expectedExchangeRate}`)
    });

    it('should calculate Exchange Rate when Liquidity Pool Balance is NOT zero and Ipor Token Total Supply is NOT zero', async () => {
        //given
        await setupTokenDaiInitialValues();
        let expectedExchangeRate = BigInt("1000000000000000000");
        const params = getStandardDerivativeParams();

        await milton.provideLiquidity(params.asset, testUtils.MILTON_14_000_USD, {from: liquidityProvider})

        //when
        let actualExchangeRate = BigInt(await iporLiquidityPool.calculateExchangeRate.call(tokenDai.address));

        //then
        assert(expectedExchangeRate === actualExchangeRate,
            `Incorrect exchange rate for DAI, actual:  ${actualExchangeRate},
            expected: ${expectedExchangeRate}`)
    });

    it('should calculate Exchange Rate when Liquidity Pool Balance is zero and Ipor Token Total Supply is NOT zero', async () => {
        //given
        await setupTokenDaiInitialValues();
        let expectedExchangeRate = BigInt("0");
        const params = getStandardDerivativeParams();

        await milton.provideLiquidity(params.asset, testUtils.MILTON_10_000_USD, {from: liquidityProvider})

        //simulation that Liquidity Pool Balance equal 0, but ipToken is not burned
        await iporAddressesManager.setAddress("MILTON", userOne);
        await miltonStorage.subtractLiquidity(params.asset, testUtils.MILTON_10_000_USD, {from: userOne});
        await iporAddressesManager.setAddress("MILTON", milton.address);

        //when
        let actualExchangeRate = BigInt(await iporLiquidityPool.calculateExchangeRate.call(tokenDai.address));

        //then
        assert(expectedExchangeRate === actualExchangeRate,
            `Incorrect exchange rate for DAI, actual:  ${actualExchangeRate},
            expected: ${expectedExchangeRate}`);

    });

    it('should calculate Exchange Rate, Exchange Rate greater than 1', async () => {
        //given
        await setupTokenDaiInitialValues();
        let expectedExchangeRate = BigInt("1002500000000000000");
        const params = getStandardDerivativeParams();
        await warren.updateIndex(params.asset, testUtils.MILTON_3_PERCENTAGE, {from: userOne});
        await milton.provideLiquidity(params.asset, BigInt("40000000000000000000"), {from: liquidityProvider})

        //open position to have something in Liquidity Pool
        await milton.openPosition(
            params.asset, BigInt("40000000000000000000"),
            params.slippageValue, params.collateralization,
            params.direction, {from: userTwo});

        //when
        let actualExchangeRate = BigInt(await iporLiquidityPool.calculateExchangeRate.call(tokenDai.address));

        //then
        assert(expectedExchangeRate === actualExchangeRate,
            `Incorrect exchange rate for DAI, actual:  ${actualExchangeRate},
            expected: ${expectedExchangeRate}`)
    });

    it('should calculate Exchange Rate when Liquidity Pool Balance is NOT zero and Ipor Token Total Supply is zero', async () => {
        //given
        let amount = BigInt("40000000000000000000");
        await setupTokenDaiInitialValues();
        let expectedExchangeRate = BigInt("1000000000000000000");
        const params = getStandardDerivativeParams();
        await warren.updateIndex(params.asset, testUtils.MILTON_3_PERCENTAGE, {from: userOne});
        await milton.provideLiquidity(params.asset, amount, {from: liquidityProvider});

        //open position to have something in Liquidity Pool
        await milton.openPosition(
            params.asset, amount,
            params.slippageValue, params.collateralization,
            params.direction, {from: userTwo});

        await milton.redeem(params.asset, amount, {from: liquidityProvider})

        //when
        let actualExchangeRate = BigInt(await iporLiquidityPool.calculateExchangeRate.call(tokenDai.address));

        //then
        assert(expectedExchangeRate === actualExchangeRate,
            `Incorrect exchange rate for DAI, actual:  ${actualExchangeRate},
            expected: ${expectedExchangeRate}`)
    });

    it('should NOT change Exchange Rate when Liquidity Provider provide liquidity, initial Exchange Rate equal to 1.5', async () => {

        //given
        let amount = BigInt("180000000000000000000");
        await setupTokenDaiInitialValues();
        const params = getStandardDerivativeParams();
        await warren.updateIndex(params.asset, testUtils.MILTON_3_PERCENTAGE, {from: userOne});
        await milton.provideLiquidity(params.asset, amount, {from: liquidityProvider});
        let oldOpeningFeePercentage = await miltonConfiguration.getOpeningFeePercentage();
        await miltonConfiguration.setOpeningFeePercentage(BigInt("600000000000000000"));

        //open position to have something in Liquidity Pool
        await milton.openPosition(
            params.asset, amount,
            params.slippageValue, params.collateralization,
            params.direction, {from: userTwo});

        //after this withdraw initial exchange rate is 1,5
        let expectedExchangeRate = BigInt("1500000000000000000");
        let exchangeRateBeforeProvideLiquidity = BigInt(await iporLiquidityPool.calculateExchangeRate.call(params.asset));
        let expectedIporTokenBalanceForUserThree = BigInt("1000000000000000000000");

        // //when
        await milton.provideLiquidity(params.asset, BigInt("1500000000000000000000"), {from: userThree});

        let actualIporTokenBalanceForUserThree = BigInt(await iporTokenDai.balanceOf.call(userThree));
        let actualExchangeRate = BigInt(await iporLiquidityPool.calculateExchangeRate.call(params.asset));

        //then
        assert(expectedIporTokenBalanceForUserThree === actualIporTokenBalanceForUserThree,
            `Incorrect ipToken Balance for asset ${params.asset} for user ${userThree}, actual:  ${actualIporTokenBalanceForUserThree},
                 expected: ${expectedIporTokenBalanceForUserThree}`)

        assert(expectedExchangeRate === exchangeRateBeforeProvideLiquidity,
            `Incorrect exchange rate before providing liquidity for DAI, actual:  ${exchangeRateBeforeProvideLiquidity},
                expected: ${expectedExchangeRate}`)

        assert(expectedExchangeRate === actualExchangeRate,
            `Incorrect exchange rate after providing liquidity for DAI, actual:  ${actualExchangeRate},
                expected: ${expectedExchangeRate}`)

        await miltonConfiguration.setOpeningFeePercentage(oldOpeningFeePercentage);
    });

    it('should NOT change Exchange Rate when Liquidity Provider provide liquidity and redeem, initial Exchange Rate equal to 1.5', async () => {
        //given
        let amount = BigInt("180000000000000000000");
        await setupTokenDaiInitialValues();
        const params = getStandardDerivativeParams();
        await warren.updateIndex(params.asset, testUtils.MILTON_3_PERCENTAGE, {from: userOne});
        await milton.provideLiquidity(params.asset, amount, {from: liquidityProvider});
        let oldOpeningFeePercentage = await miltonConfiguration.getOpeningFeePercentage();
        await miltonConfiguration.setOpeningFeePercentage(BigInt("600000000000000000"));

        //open position to have something in Liquidity Pool
        await milton.openPosition(
            params.asset, amount,
            params.slippageValue, params.collateralization,
            params.direction, {from: userTwo});

        //after this withdraw initial exchange rate is 1,5
        let expectedExchangeRate = BigInt("1500000000000000000");
        let exchangeRateBeforeProvideLiquidity = BigInt(await iporLiquidityPool.calculateExchangeRate.call(params.asset));
        let expectedIporTokenBalanceForUserThree = BigInt("0");

        //when
        await milton.provideLiquidity(params.asset, BigInt("1500000000000000000000"), {from: userThree});
        await milton.redeem(params.asset, BigInt("1000000000000000000000"), {from: userThree})

        let actualIporTokenBalanceForUserThree = BigInt(await iporTokenDai.balanceOf.call(userThree));
        let actualExchangeRate = BigInt(await iporLiquidityPool.calculateExchangeRate.call(params.asset));

        //then
        assert(expectedIporTokenBalanceForUserThree === actualIporTokenBalanceForUserThree,
            `Incorrect ipToken Balance for asset ${params.asset} for user ${userThree}, actual:  ${actualIporTokenBalanceForUserThree},
                 expected: ${expectedIporTokenBalanceForUserThree}`)

        assert(expectedExchangeRate === exchangeRateBeforeProvideLiquidity,
            `Incorrect exchange rate before providing liquidity for DAI, actual:  ${exchangeRateBeforeProvideLiquidity},
                expected: ${expectedExchangeRate}`)

        assert(expectedExchangeRate === actualExchangeRate,
            `Incorrect exchange rate after providing liquidity for DAI, actual:  ${actualExchangeRate},
                expected: ${expectedExchangeRate}`)

        await miltonConfiguration.setOpeningFeePercentage(oldOpeningFeePercentage);
    });


    it('should NOT redeem Ipor Tokens because of empty Liquidity Pool', async () => {
        //given
        await setupTokenDaiInitialValues();
        const params = getStandardDerivativeParams();
        await milton.provideLiquidity(params.asset, params.totalAmount, {from: liquidityProvider});

        //simulation that Liquidity Pool Balance equal 0, but ipToken is not burned
        await iporAddressesManager.setAddress("MILTON", userOne);
        await miltonStorage.subtractLiquidity(params.asset, params.totalAmount, {from: userOne});
        await iporAddressesManager.setAddress("MILTON", milton.address);

        //when
        await testUtils.assertError(
            //when
            milton.redeem(params.asset, BigInt("1000000000000000000000"), {from: liquidityProvider}),
            //then
            'IPOR_45'
        );
    });

    it('should NOT provide liquidity because of empty Liquidity Pool', async () => {
        //given
        await setupTokenDaiInitialValues();
        const params = getStandardDerivativeParams();
        await milton.provideLiquidity(params.asset, params.totalAmount, {from: liquidityProvider});

        //simulation that Liquidity Pool Balance equal 0, but ipToken is not burned
        await iporAddressesManager.setAddress("MILTON", userOne);
        await miltonStorage.subtractLiquidity(params.asset, params.totalAmount, {from: userOne});
        await iporAddressesManager.setAddress("MILTON", milton.address);

        //when
        await testUtils.assertError(
            //when
            milton.provideLiquidity(params.asset, params.totalAmount, {from: liquidityProvider}),
            //then
            'IPOR_45'
        );
    });

    const getStandardDerivativeParams = () => {
        return {
            asset: tokenDai.address,
            totalAmount: testUtils.MILTON_10_000_USD,
            slippageValue: 3,
            collateralization: BigInt(10000000000000000000),
            direction: 0,
            openTimestamp: Math.floor(Date.now() / 1000),
            from: userTwo
        }
    }

    const setupTokenDaiInitialValues = async () => {
        await tokenDai.setupInitialAmount(await milton.address, ZERO);
        await tokenDai.setupInitialAmount(admin, testUtils.USER_SUPPLY_18_DECIMALS);
        await tokenDai.setupInitialAmount(userOne, testUtils.USER_SUPPLY_18_DECIMALS);
        await tokenDai.setupInitialAmount(userTwo, testUtils.USER_SUPPLY_18_DECIMALS);
        await tokenDai.setupInitialAmount(userThree, testUtils.USER_SUPPLY_18_DECIMALS);
        await tokenDai.setupInitialAmount(liquidityProvider, testUtils.USER_SUPPLY_18_DECIMALS);
    }
});
