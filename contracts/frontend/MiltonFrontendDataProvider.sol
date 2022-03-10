// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../security/IporOwnableUpgradeable.sol";
import "../interfaces/IMiltonFrontendDataProvider.sol";
import "../interfaces/IIporConfiguration.sol";
import "../interfaces/IMiltonStorage.sol";
import "../interfaces/IMiltonConfiguration.sol";
import "../interfaces/IIporAssetConfiguration.sol";
import "../interfaces/IMiltonSpreadModel.sol";
import "../interfaces/IMilton.sol";
import "../interfaces/IWarren.sol";
import "../amm/MiltonStorage.sol";
import "../amm/Milton.sol";

//TODO: change name to DarcyDataProvider
contract MiltonFrontendDataProvider is
    IporOwnableUpgradeable,
    UUPSUpgradeable,
    IMiltonFrontendDataProvider
{
    IIporConfiguration internal _iporConfiguration;
    address internal _warren;
    address internal _assetDai;
    address internal _assetUsdc;
    address internal _assetUsdt;

    function initialize(
        IIporConfiguration iporConfiguration,
        address warren,
        address assetDai,
        address assetUsdt,
        address assetUsdc
    ) public initializer {
        __Ownable_init();
        _iporConfiguration = iporConfiguration;
        _warren = warren;
        _assetDai = assetDai;
        _assetUsdc = assetUsdc;
        _assetUsdt = assetUsdt;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function getIpTokenExchangeRate(address asset)
        external
        view
        override
        returns (uint256)
    {
        IIporAssetConfiguration assetConfiguration = IIporAssetConfiguration(
            _iporConfiguration.getIporAssetConfiguration(asset)
        );
        IMilton milton = IMilton(assetConfiguration.getMilton());
        uint256 result = milton.calculateExchangeRate(block.timestamp);
        return result;
    }

    function getTotalOutstandingNotional(address asset)
        external
        view
        override
        returns (uint256 payFixedTotalNotional, uint256 recFixedTotalNotional)
    {
        IIporAssetConfiguration assetConfiguration = IIporAssetConfiguration(
            _iporConfiguration.getIporAssetConfiguration(asset)
        );
        IMiltonStorage miltonStorage = IMiltonStorage(
            assetConfiguration.getMiltonStorage()
        );
        (payFixedTotalNotional, recFixedTotalNotional) = miltonStorage
            .getTotalOutstandingNotional();
    }

    function getMySwaps(address asset, uint256 offset, uint256 pageSize)
        external
        view
        override
        returns (IporSwapFront[] memory items)
    {
        require(pageSize != 0, IporErrors.PAGE_SIZE_EQUAL_ZERO);

        IIporAssetConfiguration assetConfiguration = IIporAssetConfiguration(
            _iporConfiguration.getIporAssetConfiguration(asset)
        );

        IMiltonStorage miltonStorage = IMiltonStorage(
            assetConfiguration.getMiltonStorage()
        );

        uint128[] memory accountSwapPayFixedIds = miltonStorage
            .getSwapPayFixedIds(msg.sender);

        uint128[] memory accountSwapReceiveFixedIds = miltonStorage
            .getSwapReceiveFixedIds(msg.sender);

        SwapIdDirectionPair[] memory swapIds = new SwapIdDirectionPair[](
            accountSwapPayFixedIds.length + accountSwapReceiveFixedIds.length
        );
        uint256 i = 0;
        for (i = 0; i < accountSwapPayFixedIds.length; i++) {
            swapIds[i] = SwapIdDirectionPair(accountSwapPayFixedIds[i], 0);
        }
        for (i = 0; i < accountSwapReceiveFixedIds.length; i++) {
            swapIds[accountSwapReceiveFixedIds.length + i] = SwapIdDirectionPair(accountSwapReceiveFixedIds[i], 1);
        }

        IMilton milton = IMilton(assetConfiguration.getMilton());

        uint256 resultSetSize = _resolveResultSetSize(swapIds.length, offset, pageSize);
        IporSwapFront[] memory iporDerivatives = new IporSwapFront[](resultSetSize);
        for (i = 0; i != resultSetSize; i++) {
            SwapIdDirectionPair memory swapIdPair = swapIds[i + offset];
            if (swapIdPair.direction == 0) {
                DataTypes.IporSwapMemory memory iporSwap = miltonStorage.getSwapPayFixed(swapIdPair.swapId);
                iporDerivatives[i] = _mapToIporSwapFront(
                    asset,
                    iporSwap,
                    0,
                    milton.calculateSwapPayFixedValue(iporSwap)
                );
            } else {
                DataTypes.IporSwapMemory memory iporSwap = miltonStorage.getSwapReceiveFixed(swapIdPair.swapId);
                iporDerivatives[i] = _mapToIporSwapFront(
                    asset,
                    iporSwap,
                    1,
                    milton.calculateSwapReceiveFixedValue(iporSwap));
            }
        }

        return iporDerivatives;
    }

    function _resolveResultSetSize(
        uint256 totalSwapNumber,
        uint256 offset,
        uint256 pageSize
    ) internal view returns (uint256)
    {
        uint256 resultSetSize;
        if (offset > totalSwapNumber) {
            resultSetSize = 0;
        } else if (offset + pageSize < totalSwapNumber) {
            resultSetSize = pageSize;
        } else {
            resultSetSize = totalSwapNumber - offset;
        }

        return resultSetSize;
    }

    function _mapToIporSwapFront(
        address asset,
        DataTypes.IporSwapMemory memory iporSwap,
        uint8 direction,
        int256 value
    ) internal view returns (IporSwapFront memory)
    {
        return IporSwapFront(
            iporSwap.id,
            asset,
            iporSwap.collateral,
            iporSwap.notionalAmount,
            IporMath.division(
                iporSwap.notionalAmount * Constants.D18,
                iporSwap.collateral
            ),
            direction,
            iporSwap.fixedInterestRate,
            value,
            iporSwap.startingTimestamp,
            iporSwap.endingTimestamp,
            iporSwap.liquidationDepositAmount
        );
    }

    function getConfiguration()
        external
        view
        override
        returns (IporAssetConfigurationFront[] memory)
    {
        uint256 timestamp = block.timestamp;

        IporAssetConfigurationFront[]
            memory iporAssetConfigurationsFront = new IporAssetConfigurationFront[](
                3
            );

        iporAssetConfigurationsFront[0] = _createIporAssetConfFront(
            _assetDai,
            timestamp
        );
        iporAssetConfigurationsFront[1] = _createIporAssetConfFront(
            _assetUsdt,
            timestamp
        );
        iporAssetConfigurationsFront[2] = _createIporAssetConfFront(
            _assetUsdc,
            timestamp
        );
        return iporAssetConfigurationsFront;
    }

    function _createIporAssetConfFront(address asset, uint256 timestamp)
        internal
        view
        returns (IporAssetConfigurationFront memory iporAssetConfigurationFront)
    {
        IIporAssetConfiguration iporAssetConfiguration = IIporAssetConfiguration(
                _iporConfiguration.getIporAssetConfiguration(asset)
            );
        IMiltonStorage miltonStorage = IMiltonStorage(
            iporAssetConfiguration.getMiltonStorage()
        );
        address miltonAddr = iporAssetConfiguration.getMilton();
        IMiltonConfiguration milton = IMiltonConfiguration(miltonAddr);

        IMiltonSpreadModel spreadModel = IMiltonSpreadModel(
            milton.getMiltonSpreadModel()
        );

        DataTypes.AccruedIpor memory accruedIpor = IWarren(_warren)
            .getAccruedIndex(timestamp, asset);

        DataTypes.MiltonBalanceMemory memory balance = IMilton(miltonAddr)
            .getAccruedBalance();

        uint256 spreadPayFixedValue = spreadModel.calculateSpreadPayFixed(
            miltonStorage.calculateSoapPayFixed(
                accruedIpor.ibtPrice,
                timestamp
            ),
            accruedIpor,
            balance
        );

        uint256 spreadRecFixedValue = spreadModel.calculateSpreadRecFixed(
            miltonStorage.calculateSoapReceiveFixed(
                accruedIpor.ibtPrice,
                timestamp
            ),
            accruedIpor,
            balance
        );

        iporAssetConfigurationFront = IporAssetConfigurationFront(
            asset,
            milton.getMinCollateralizationFactorValue(),
            milton.getMaxCollateralizationFactorValue(),
            milton.getOpeningFeePercentage(),
            milton.getIporPublicationFeeAmount(),
            milton.getLiquidationDepositAmount(),
            milton.getIncomeTaxPercentage(),
            spreadPayFixedValue,
            spreadRecFixedValue
        );
    }

    struct SwapIdDirectionPair {
        uint128 swapId;
        uint8 direction;
    }
}
