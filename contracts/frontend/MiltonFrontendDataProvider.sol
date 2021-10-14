// SPDX-License-Identifier: agpl-3.0
pragma solidity >=0.8.4 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IMiltonFrontendDataProvider.sol";
import "../interfaces/IIporAddressesManager.sol";
import "../interfaces/IMiltonStorage.sol";
import "../interfaces/IIporConfiguration.sol";
import "../interfaces/IMiltonSpreadStrategy.sol";

contract MiltonFrontendDataProvider is IMiltonFrontendDataProvider {

    IIporAddressesManager public immutable addressesManager;

    constructor(IIporAddressesManager _addressesManager) {
        addressesManager = _addressesManager;
    }

    function getMyPositions() external override view returns (IporDerivativeFront[] memory items) {
        IMiltonStorage miltonStorage = IMiltonStorage(addressesManager.getMiltonStorage());
        uint256[] memory userDerivativesIds = miltonStorage.getUserDerivativeIds(msg.sender);
        IporDerivativeFront[] memory iporDerivatives = new IporDerivativeFront[](userDerivativesIds.length);

        for (uint256 i = 0; i < userDerivativesIds.length; i++) {
            DataTypes.MiltonDerivativeItem memory derivativeItem = miltonStorage.getDerivativeItem(userDerivativesIds[i]);

            iporDerivatives[i] = IporDerivativeFront(
                derivativeItem.item.id,
                derivativeItem.item.asset,
                derivativeItem.item.collateral,
                derivativeItem.item.notionalAmount,
                derivativeItem.item.collateralizationFactor,
                derivativeItem.item.direction,
                derivativeItem.item.indicator.fixedInterestRate,
                derivativeItem.item.startingTimestamp,
                derivativeItem.item.endingTimestamp
            );
        }

        return iporDerivatives;
    }

    function getConfiguration() external override view returns (IporConfigurationFront memory iporConfigurationFront) {
        IIporConfiguration iporConfiguration = IIporConfiguration(addressesManager.getIporConfiguration());
        address[] memory assets = addressesManager.getAssets();
        IMiltonSpreadStrategy spreadStrategy = IMiltonSpreadStrategy(addressesManager.getMiltonSpreadStrategy());
        IporSpreadFront[] memory spreads = new IporSpreadFront[](assets.length);

        for (uint256 i = 0; i < assets.length; i++) {
            (uint256 spreadPayFixedValue, uint256 spreadRecFixedValue) = spreadStrategy.calculateSpread(assets[i], block.timestamp);
            spreads[i] = IporSpreadFront(assets[i], spreadPayFixedValue, spreadRecFixedValue);
        }

        return IporConfigurationFront(
            iporConfiguration.getMinCollateralizationFactorValue(),
            iporConfiguration.getMaxCollateralizationFactorValue(),
            iporConfiguration.getOpeningFeePercentage(),
            iporConfiguration.getIporPublicationFeeAmount(),
            iporConfiguration.getLiquidationDepositAmount(),
            iporConfiguration.getIncomeTaxPercentage(),
            spreads
        );
    }
}
