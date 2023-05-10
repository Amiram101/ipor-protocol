// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.16;

import "../../itf/ItfMilton.sol";

contract MockCase8MiltonDai is ItfMilton {
    IMiltonStorage _mockMiltonStorage;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address iporRiskManagementOracle) ItfMilton(iporRiskManagementOracle) {
    }


    function _getMaxSwapCollateralAmount() internal pure virtual override returns (uint256) {
        return 1e23;
    }

    function _getIncomeFeeRate() internal pure virtual override returns (uint256) {
        return 1e17;
    }

    function _getOpeningFeeRate() internal pure virtual override returns (uint256) {
        return 3e14;
    }

    function _getOpeningFeeTreasuryPortionRate() internal pure virtual override returns (uint256) {
        return 0;
    }

    function _getIporPublicationFee() internal pure virtual override returns (uint256) {
        return 100000 * 1e18;
    }

    function _getLiquidationDepositAmount() internal pure virtual override returns (uint256) {
        return 20;
    }

    function _getMinLeverage() internal pure virtual override returns (uint256) {
        return 10 * 1e18;
    }

    function _getDecimals() internal pure virtual override returns (uint256) {
        return 18;
    }

    function setMockMiltonStorage(address mockMiltonStorage) external {
        _mockMiltonStorage = IMiltonStorage(mockMiltonStorage);
    }

    function _getMiltonStorage() internal view override returns (IMiltonStorage) {
        if (address(_mockMiltonStorage) != address(0)) {
            return _mockMiltonStorage;
        }
        return _miltonStorage;
    }
}
