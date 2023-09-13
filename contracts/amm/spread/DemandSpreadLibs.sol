// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "../../amm/spread/CalculateTimeWeightedNotionalLibs.sol";

library DemandSpreadLibs {
    uint256 internal constant INTERVAL_ONE = 1e17;
    uint256 internal constant INTERVAL_TWO = 2e17;
    uint256 internal constant INTERVAL_THREE = 3e17;
    uint256 internal constant INTERVAL_FOUR = 4e17;
    uint256 internal constant INTERVAL_FIVE = 5e17;
    uint256 internal constant INTERVAL_SIX = 8e17;
    uint256 internal constant INTERVAL_SEVEN = 1e18;

    uint256 internal constant SLOPE_ONE = 5e16;
    uint256 internal constant BASE_ONE = 1e18;

    uint256 internal constant SLOPE_TWO = 1e17;
    uint256 internal constant BASE_TWO = 5e15;

    uint256 internal constant SLOPE_THREE = 15e16;
    uint256 internal constant BASE_THREE = 15e15;

    uint256 internal constant SLOPE_FOUR = 2e17;
    uint256 internal constant BASE_FOUR = 3e16;

    uint256 internal constant SLOPE_FIVE = 5e17;
    uint256 internal constant BASE_FIVE = 15e16;

    uint256 internal constant SLOPE_SIX = 333333333333333333;
    uint256 internal constant BASE_SIX = 66666666666666666;

    uint256 internal constant SLOPE_SEVEN = 5e17;
    uint256 internal constant BASE_SEVEN = 2e17;

    /// @notice DTO for the Weighted Notional
    struct SpreadInputData {
        /// @notice Swap's balance for Pay Fixed leg
        uint256 totalCollateralPayFixed;
        /// @notice Swap's balance for Receive Fixed leg
        uint256 totalCollateralReceiveFixed;
        /// @notice Liquidity Pool's Balance
        uint256 liquidityPoolBalance;
        /// @notice Swap's notional
        uint256 swapNotional;
        /// @notice demand spread factor used in demand spread calculation, value without decimals
        uint256 demandSpreadFactor;
        /// @notice List of supported tenors in seconds
        uint256[] tenorsInSeconds;
        /// @notice List of storage ids for a TimeWeightedNotional for all tenors for a given asset
        SpreadStorageLibs.StorageId[] timeWeightedNotionalStorageIds;
        /// @notice Storage id for a TimeWeightedNotional for a specific tenor and asset.
        SpreadStorageLibs.StorageId timeWeightedNotionalStorageId;
        // @notice Calculation for tenor in seconds
        uint256 selectedTenorInSeconds;
    }

    /// @notice Gets the spread function configuration.
    function spreadFunctionConfig() public pure returns (uint256[] memory) {
        uint256[] memory config = new uint256[](21);
        config[0] = INTERVAL_ONE;
        config[1] = INTERVAL_TWO;
        config[2] = INTERVAL_THREE;
        config[3] = INTERVAL_FOUR;
        config[4] = INTERVAL_FIVE;
        config[5] = INTERVAL_SIX;
        config[6] = INTERVAL_SEVEN;
        config[7] = SLOPE_ONE;
        config[8] = BASE_ONE;
        config[9] = SLOPE_TWO;
        config[10] = BASE_TWO;
        config[11] = SLOPE_THREE;
        config[12] = BASE_THREE;
        config[13] = SLOPE_FOUR;
        config[14] = BASE_FOUR;
        config[15] = SLOPE_FIVE;
        config[16] = BASE_FIVE;
        config[17] = SLOPE_SIX;
        config[18] = BASE_SIX;
        config[19] = SLOPE_SEVEN;
        config[20] = BASE_SEVEN;
        return config;
    }

    /// @notice Calculates the spread value for the pay-fixed side based on the provided input data.
    /// @param inputData The input data required for the calculation, including liquidity pool information and collateral amounts.
    /// @return spreadValue The calculated spread value for the pay-fixed side.
    function calculatePayFixedSpread(SpreadInputData memory inputData) internal view returns (uint256 spreadValue) {
        uint256 lpDepth = CalculateTimeWeightedNotionalLibs.calculateLpDepth(
            inputData.liquidityPoolBalance,
            inputData.totalCollateralPayFixed,
            inputData.totalCollateralReceiveFixed
        );

        /// @dev demandSpreadFactor is without decimals.
        uint256 notionalDepth = lpDepth * inputData.demandSpreadFactor;

        (
            uint256 oldWeightedNotionalPayFixed,
            uint256 timeWeightedNotionalReceiveFixed
        ) = CalculateTimeWeightedNotionalLibs.getTimeWeightedNotional(
                inputData.timeWeightedNotionalStorageIds,
                inputData.tenorsInSeconds,
                inputData.selectedTenorInSeconds
            );

        uint256 newWeightedNotionalPayFixed = oldWeightedNotionalPayFixed + inputData.swapNotional;

        if (newWeightedNotionalPayFixed > timeWeightedNotionalReceiveFixed) {
            uint256 oldSpread;

            if (oldWeightedNotionalPayFixed > timeWeightedNotionalReceiveFixed) {
                oldSpread = calculateSpreadFunction(
                    notionalDepth,
                    oldWeightedNotionalPayFixed - timeWeightedNotionalReceiveFixed
                );
            }

            uint256 newSpread = calculateSpreadFunction(
                notionalDepth,
                newWeightedNotionalPayFixed - timeWeightedNotionalReceiveFixed
            );

            spreadValue = IporMath.division(oldSpread + newSpread, 2);
        } else {
            spreadValue = 0;
        }
    }

    /// @notice Calculates the spread value for the receive-fixed side based on the provided input data.
    /// @param inputData The input data required for the calculation, including liquidity pool information and collateral amounts.
    /// @return spreadValue The calculated spread value for the receive-fixed side.
    function calculateReceiveFixedSpread(SpreadInputData memory inputData) internal view returns (uint256 spreadValue) {
        uint256 lpDepth = CalculateTimeWeightedNotionalLibs.calculateLpDepth(
            inputData.liquidityPoolBalance,
            inputData.totalCollateralPayFixed,
            inputData.totalCollateralReceiveFixed
        );

        /// @dev demandSpreadFactor is without decimals.
        uint256 notionalDepth = lpDepth * inputData.demandSpreadFactor;

        (
            uint256 timeWeightedNotionalPayFixed,
            uint256 oldWeightedNotionalReceiveFixed
        ) = CalculateTimeWeightedNotionalLibs.getTimeWeightedNotional(
                inputData.timeWeightedNotionalStorageIds,
                inputData.tenorsInSeconds,
                inputData.selectedTenorInSeconds
            );

        uint256 newWeightedNotionalReceiveFixed = oldWeightedNotionalReceiveFixed + inputData.swapNotional;

        if (newWeightedNotionalReceiveFixed > timeWeightedNotionalPayFixed) {
            uint256 oldSpread;

            if (oldWeightedNotionalReceiveFixed > timeWeightedNotionalPayFixed) {
                oldSpread = calculateSpreadFunction(
                    notionalDepth,
                    oldWeightedNotionalReceiveFixed - timeWeightedNotionalPayFixed
                );
            }

            uint256 newSpread = calculateSpreadFunction(
                notionalDepth,
                newWeightedNotionalReceiveFixed - timeWeightedNotionalPayFixed
            );

            spreadValue = IporMath.division(oldSpread + newSpread, 2);
        } else {
            spreadValue = 0;
        }
    }

    /// @notice Calculates the spread value based on the given maximum notional and weighted notional.
    /// @param maxNotional The maximum notional value determined by lpDepth and demandSpreadFactor from Risk Oracle
    /// @param weightedNotional The weighted notional value used in the spread calculation.
    /// @return spreadValue The calculated spread value based on the given inputs.
    /// @dev maxNotional = lpDepth * demandSpreadFactor
    function calculateSpreadFunction(
        uint256 maxNotional,
        uint256 weightedNotional
    ) public pure returns (uint256 spreadValue) {
        uint256 ratio = IporMath.division(weightedNotional * 1e18, maxNotional);
        if (ratio < 1e17) {
            spreadValue = IporMath.division(SLOPE_ONE * ratio, BASE_ONE);
            /// @dev spreadValue in range < 0%, 0.5% )
        } else if (ratio < 2e17) {
            spreadValue = IporMath.division(SLOPE_TWO * ratio, 1e18) - BASE_TWO;
            /// @dev spreadValue in range < 0.5%, 1.5% )
        } else if (ratio < 3e17) {
            spreadValue = IporMath.division(SLOPE_THREE * ratio, 1e18) - BASE_THREE;
            /// @dev spreadValue in range < 1.5%, 3% )
        } else if (ratio < 4e17) {
            spreadValue = IporMath.division(SLOPE_FOUR * ratio, 1e18) - BASE_FOUR;
            /// @dev spreadValue in range < 3%, 5% )
        } else if (ratio < 5e17) {
            spreadValue = IporMath.division(SLOPE_FIVE * ratio, 1e18) - BASE_FIVE;
            /// @dev spreadValue in range < 5%, 10% )
        } else if (ratio < 8e17) {
            spreadValue = IporMath.division(SLOPE_SIX * ratio, 1e18) - BASE_SIX;
            /// @dev spreadValue in range < 10%, 20% )
        } else if (ratio < 1e18) {
            spreadValue = IporMath.division(SLOPE_SEVEN * ratio, 1e18) - BASE_SEVEN;
            /// @dev spreadValue in range < 20%, 30% )
        } else {
            spreadValue = 3 * 1e17;
            /// @dev spreadValue in range < 30%, 100% >
        }
    }
}
