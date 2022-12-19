// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../TestCommons.sol";
import "../../contracts/mocks/spread/MockBaseMiltonSpreadModelDai.sol";
import "../../contracts/interfaces/types/IporTypes.sol";

contract MiltonSpreadPayFixedTest is Test, TestCommons {
    MockBaseMiltonSpreadModelDai internal _miltonSpread;
    address internal _admin;
    address internal _userOne;

    function setUp() public {
        _miltonSpread = new MockBaseMiltonSpreadModelDai();
        _admin = address(this);
        _userOne = _getUserAddress(1);
    }

	function testShouldCalculateQuoteValuePayFixedSpreadPremiumsPositiveAndBiggerThanIpor() public {
		// given
		uint256 liquidityPoolBalance = 15000 * 10 ** 18;
		uint256 swapCollateral = 10000 * 10 ** 18;
		uint256 openingFee = 20 * 10 ** 18;
		IporTypes.AccruedIpor memory accruedIpor = IporTypes.AccruedIpor(
			13 * 10**16, // indexValue: 13%
			1 * 10**18, // ibtPrice: 1
			1 * 10**16, // exponentialMovingAverage: 1%
			15 * 10**15 // exponentialWeightedMovingVariance: 0.15%
		);
		IporTypes.MiltonBalancesMemory memory accruedBalance = IporTypes.MiltonBalancesMemory(
			10000 * 10 ** 18 + swapCollateral, // totalCollateralPayFixed 
			13000 * 10 ** 18, // totalCollateralReceiveFixed
			liquidityPoolBalance + openingFee, // liquidityPool
			0 // vault
		);
		uint256 expectedQuoteValue = 3222138708849583098;
		// when
		vm.prank(_userOne);
		uint256 actualQuotedValue = _miltonSpread.calculateQuotePayFixed(accruedIpor, accruedBalance);
		// then
		assertEq(actualQuotedValue, expectedQuoteValue);
		assertLe(accruedIpor.indexValue, actualQuotedValue);
	}

	function testShouldCalculateQuoteValuePayFixedSpreadPremiumsPositive() public {
		// given
		uint256 liquidityPoolBalance = 15000 * 10 ** 18;
		uint256 swapCollateral = 10000 * 10 ** 18;
		uint256 openingFee = 20 * 10 ** 18;
		IporTypes.AccruedIpor memory accruedIpor = IporTypes.AccruedIpor(
			2 * 10**16, // indexValue: 2%
			1 * 10**18, // ibtPrice: 1
			1 * 10**16, // exponentialMovingAverage: 1%
			15 * 10**15 // exponentialWeightedMovingVariance: 0.15%
		);
		IporTypes.MiltonBalancesMemory memory accruedBalance = IporTypes.MiltonBalancesMemory(
			10000 * 10 ** 18 + swapCollateral, // totalCollateralPayFixed 
			13000 * 10 ** 18, // totalCollateralReceiveFixed
			liquidityPoolBalance + openingFee, // liquidityPool
			0 // vault
		);
		uint256 expectedQuoteValue = 3218095531900806724;
		// when
		vm.prank(_userOne);
		uint256 actualQuotedValue = _miltonSpread.calculateQuotePayFixed(accruedIpor, accruedBalance);
		// then
		assertEq(actualQuotedValue, expectedQuoteValue);
	}

}
