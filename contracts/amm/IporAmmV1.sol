// SPDX-License-Identifier: agpl-3.0
pragma solidity >=0.8.4 <0.9.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Errors} from '../Errors.sol';
import {DataTypes} from '../libraries/types/DataTypes.sol';
import "../interfaces/IIporOracle.sol";
import './IporAmmStorage.sol';
import './IporAmmEvents.sol';
import './IporPool.sol';
import "../libraries/types/DataTypes.sol";

/**
 * @title Automated Market Maker for derivatives based on IPOR Index.
 *
 * @author IPOR Labs
 */
contract IporAmmV1 is IporAmmV1Storage, IporAmmV1Events {

    IIporOracle public iporOracle;

    //@notice By default every derivative takes 28 days, this variable show this value in seconds
    uint256 constant DERIVATIVE_DEFAULT_PERIOD_IN_SECONDS = 60 * 60 * 24 * 28;

    //@notice amount of asset taken in case of deposit liquidation
    uint256 constant LIQUIDATION_DEPOSIT_FEE_AMOUNT = 20 * 1e18;

    //@notice percentage of deposit amount
    uint256 constant OPENING_FEE_PERCENTAGE = 1e16;

    //@notice amount of asset taken for IPOR publication
    uint256 constant IPOR_PUBLICATION_FEE_AMOUNT = 10 * 1e18;

    //@notice percentage of deposit amount
    uint256 constant SPREAD_FEE_PERCENTAGE = 1e16;


    constructor(address _iporOracle, address _usdtToken, address _usdcToken, address _daiToken) {

        admin = msg.sender;

        iporOracle = IIporOracle(_iporOracle);

        tokens["USDT"] = _usdtToken;
        tokens["USDC"] = _usdcToken;
        tokens["DAI"] = _daiToken;

        //TODO: allow admin to setup it during runtime
        closingFeePercentage = 0;

    }

    /**
    * @notice Trader open new derivative position. Depending on the direction it could be derivative
    * where trader pay fixed and receive a floating (long position) or receive fixed and pay a floating.
    * @param _asset symbol of asset of the derivative
    * @param _totalAmount sum of deposit amount and fees
    * @param _leverage leverage level - proportion between _depositAmount and notional amount
    * @param _direction pay fixed and receive a floating (trader assume that interest rate will increase)
    * or receive a floating and pay fixed (trader assume that interest rate will decrease)
    * In a long position the trader will pay a fixed rate and receive a floating rate.
    */
    function openPosition(
        string memory _asset,
        uint256 _totalAmount,
        uint256 _maximumSlippage,
        uint8 _leverage,
        uint8 _direction) public {

        require(_leverage > 0, Errors.AMM_LEVERAGE_TOO_LOW);
        require(_totalAmount > 0, Errors.AMM_TOTAL_AMOUNT_TOO_LOW);
        require(_totalAmount > LIQUIDATION_DEPOSIT_FEE_AMOUNT + IPOR_PUBLICATION_FEE_AMOUNT, Errors.AMM_TOTAL_AMOUNT_LOWER_THAN_FEE);
        require(_totalAmount <= 1e24, Errors.AMM_TOTAL_AMOUNT_TOO_HIGH);
        require(_maximumSlippage > 0, Errors.AMM_MAXIMUM_SLIPPAGE_TOO_LOW);
        require(_maximumSlippage <= 1e20, Errors.AMM_MAXIMUM_SLIPPAGE_TOO_HIGH);
        require(tokens[_asset] != address(0), Errors.AMM_LIQUIDITY_POOL_NOT_EXISTS);
        require(_direction <= uint8(DataTypes.DerivativeDirection.PayFloatingReceiveFixed), Errors.AMM_DERIVATIVE_DIRECTION_NOT_EXISTS);
        require(IERC20(tokens[_asset]).balanceOf(msg.sender) >= _totalAmount, Errors.AMM_ASSET_BALANCE_OF_TOO_LOW);
        //TODO consider check if it is smart contract, if yes then revert
        DataTypes.IporDerivativeAmount memory derivativeAmount = _calculateDerivativeAmount(_totalAmount, _leverage);
        require(_totalAmount > LIQUIDATION_DEPOSIT_FEE_AMOUNT + IPOR_PUBLICATION_FEE_AMOUNT + derivativeAmount.openingFee, Errors.AMM_TOTAL_AMOUNT_LOWER_THAN_FEE);

        (uint256 iporIndexValue, uint256  ibtPrice,) = iporOracle.getIndex(_asset);

        DataTypes.IporDerivativeIndicator memory indicator = DataTypes.IporDerivativeIndicator(
            iporIndexValue,
            ibtPrice,
            _calculateIbtQuantity(_asset, derivativeAmount.notional),
            _direction == 0 ? (iporIndexValue + SPREAD_FEE_PERCENTAGE) : (iporIndexValue - SPREAD_FEE_PERCENTAGE),
            soap
        );

        DataTypes.IporDerivativeFee memory fee = DataTypes.IporDerivativeFee(
            LIQUIDATION_DEPOSIT_FEE_AMOUNT,
            derivativeAmount.openingFee,
            IPOR_PUBLICATION_FEE_AMOUNT,
            SPREAD_FEE_PERCENTAGE);

        uint256 startingTimestamp = block.timestamp;

        derivatives.push(
            DataTypes.IporDerivative(
                nextDerivativeId,
                DataTypes.DerivativeState.ACTIVE,
                msg.sender,
                _asset,
                _direction,
                derivativeAmount.deposit,
                fee,
                _leverage,
                derivativeAmount.notional,
                startingTimestamp,
                startingTimestamp + DERIVATIVE_DEFAULT_PERIOD_IN_SECONDS,
                indicator
            )
        );

        nextDerivativeId++;

        IERC20(tokens[_asset]).transferFrom(msg.sender, address(this), _totalAmount);

        derivativesTotalBalances[_asset] = derivativesTotalBalances[_asset] + derivativeAmount.deposit;
        openingFeeTotalBalances[_asset] = openingFeeTotalBalances[_asset] + derivativeAmount.openingFee;
        liquidationDepositFeeTotalBalances[_asset] = liquidationDepositFeeTotalBalances[_asset] + LIQUIDATION_DEPOSIT_FEE_AMOUNT;
        iporPublicationFeeTotalBalances[_asset] = iporPublicationFeeTotalBalances[_asset] + IPOR_PUBLICATION_FEE_AMOUNT;
        liquidityPoolTotalBalances[_asset] = liquidityPoolTotalBalances[_asset] + derivativeAmount.openingFee;

        emit OpenPosition(
            nextDerivativeId,
            msg.sender,
            _asset,
            DataTypes.DerivativeDirection(_direction),
            derivativeAmount.deposit,
            fee,
            _leverage,
            derivativeAmount.notional,
            startingTimestamp,
            startingTimestamp + DERIVATIVE_DEFAULT_PERIOD_IN_SECONDS,
            indicator
        );

        //TODO: clarify if ipAsset should be transfered to trader when position is opened
    }

    function closePosition(uint256 _derivativeId) public {
        //TODO: check based on algorithms

        derivatives[_derivativeId].state = DataTypes.DerivativeState.INACTIVE;
        uint256 deposit = derivatives[_derivativeId].depositAmount;
        uint256 fixedRate = derivatives[_derivativeId].indicator.fixedInterestRate;
        //uint256 floatingRate = iporOracle.getIndex(derivatives[_derivativeId].asset);
        uint256 I = 0;

        //pay fixed, receive floating
        if (derivatives[_derivativeId].direction == 0) {

        }

        //receive fixed, pay floating
        if (derivatives[_derivativeId].direction == 1) {

        }

        //TODO: check if

        //TODO: rebalance soap
    }

    function provideLiquidity(string memory _asset, uint256 _liquidityAmount) public {
        liquidityPoolTotalBalances[_asset] = liquidityPoolTotalBalances[_asset] + _liquidityAmount;
        IERC20(tokens[_asset]).transferFrom(msg.sender, address(this), _liquidityAmount);
    }

    function _calculcatePayout() internal returns (uint256) {
        return 1e10;
    }

    function _calculateClosingFeeAmount(uint256 depositAmount) internal returns (uint256) {
        return depositAmount * closingFeePercentage / 1e20;
    }

    function _calculateDerivativeAmount(
        uint256 _totalAmount, uint8 _leverage
    ) internal pure returns (DataTypes.IporDerivativeAmount memory) {
        uint256 openingFeeAmount = (_totalAmount - LIQUIDATION_DEPOSIT_FEE_AMOUNT - IPOR_PUBLICATION_FEE_AMOUNT) * OPENING_FEE_PERCENTAGE / 1e18;
        uint256 depositAmount = _totalAmount - LIQUIDATION_DEPOSIT_FEE_AMOUNT - IPOR_PUBLICATION_FEE_AMOUNT - openingFeeAmount;
        return DataTypes.IporDerivativeAmount(
            depositAmount,
            _leverage * depositAmount,
            openingFeeAmount
        );
    }

    function _calculateIbtQuantity(string memory _asset, uint256 _notionalAmount) internal view returns (uint256){
        (, uint256 _ibtPrice,) = iporOracle.getIndex(_asset);
        return _notionalAmount / _ibtPrice;
    }

    //@notice FOR FRONTEND
    function getTotalSupply(string memory _asset) external view returns (uint256) {
        ERC20 token = ERC20(tokens[_asset]);
        return token.balanceOf(address(this));
    }

    //@notice FOR FRONTEND
    function getOpenPositions() external view returns (DataTypes.IporDerivative[] memory) {
        DataTypes.IporDerivative[] memory _derivatives = new DataTypes.IporDerivative[](derivatives.length);

        for (uint256 i = 0; i < derivatives.length; i++) {
            DataTypes.IporDerivativeIndicator memory indicator = DataTypes.IporDerivativeIndicator(
                derivatives[i].indicator.iporIndexValue,
                derivatives[i].indicator.ibtPrice,
                derivatives[i].indicator.ibtQuantity,
                derivatives[i].indicator.fixedInterestRate,
                derivatives[i].indicator.soap
            );

            DataTypes.IporDerivativeFee memory fee = DataTypes.IporDerivativeFee(
                derivatives[i].fee.liquidationDepositAmount,
                derivatives[i].fee.openingAmount,
                derivatives[i].fee.iporPublicationAmount,
                derivatives[i].fee.spreadPercentage
            );
            _derivatives[i] = DataTypes.IporDerivative(
                derivatives[i].id,
                derivatives[i].state,
                derivatives[i].buyer,
                derivatives[i].asset,
                derivatives[i].direction,
                derivatives[i].depositAmount,
                fee,
                derivatives[i].leverage,
                derivatives[i].notionalAmount,
                derivatives[i].startingTimestamp,
                derivatives[i].endingTimestamp,
                indicator
            );

        }

        return _derivatives;

    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `3`, a balance of `707` tokens should
     * be displayed to a user as `0,707` (`707 / 10 ** 3`).
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @notice Modifier which checks if caller is admin for this contract
     */
    modifier onlyAdmin() {
        require(msg.sender == admin, Errors.CALLER_NOT_IPOR_ORACLE_ADMIN);
        _;
    }
}