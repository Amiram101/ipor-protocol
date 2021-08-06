// SPDX-License-Identifier: agpl-3.0
pragma solidity >=0.8.4 <0.9.0;

library DataTypes {

    struct ConfigParams {
        uint256 incomeTax;
        uint256 liquidationDepositFeeAmount;
        uint256 openingAmount;
        uint256 iporPublicationAmount;
        uint256 liquiditiMaxUtilizationRate;

        //this treasurer manage ipor publication fee balance
        address charlieTreasurer;

        //this treasurer manage opening fee balance
        address treasureTreasurer;
    }

    struct TotalSoapIndicator {
        SoapIndicator pf;
        SoapIndicator rf;
    }

    struct TotalSpreadIndicator {
        SpreadIndicator pf;
        SpreadIndicator rf;
    }

    struct SpreadIndicator {
        uint256 spread;
    }

    //soap payfixed and soap recfixed indicators
    struct SoapIndicator {

        uint256 rebalanceTimestamp;
        //leg
        DataTypes.DerivativeDirection direction;
        //O_0
        uint256 hypotheticalInterestCumulative;
        //N_0
        uint256 totalNotional;
        //I_0
        uint256 averageInterestRate;
        //TT
        uint256 totalIbtQuantity;
        //SOAP
        int256 soap;

    }

    //@notice IPOR Structure
    struct IPOR {

        //@notice Asset Symbol like USDT, USDC, DAI etc.
        string asset;

        //@notice IPOR Index Value
        uint256 indexValue;

        //@notice Interest Bearing Token Price
        uint256 ibtPrice;

        //@notice block timestamp
        uint256 blockTimestamp;
    }

    //@notice Derivative direction (long = pay fixed and receive a floating or short = receive fixed and pay a floating)
    enum DerivativeDirection {

        //@notice In long position the trader will pay a fixed rate and receive a floating rate.
        PayFixedReceiveFloating,

        //@notice In short position the trader will receive fixed rate and pay a floating rate.
        PayFloatingReceiveFixed
    }

    enum DerivativeState {
        ACTIVE, INACTIVE, PENDING
    }

    struct IporDerivativeInterest {
        uint256 interestFixed;
        uint256 interestFloating;
        int256 interestDifferenceAmount;
    }

    struct IporDerivativeAmount {
        uint256 deposit;
        uint256 notional;
        uint256 openingFee;
    }

    struct IporDerivativeIndicator {
        //@notice IPOR Index value indicator
        uint256 iporIndexValue;

        //@notice IPOR Interest Bearing Token price
        uint256 ibtPrice;

        //@notice IPOR Interest Bearing Token quantity
        uint256 ibtQuantity;

        //@notice Fixed interest rate at which the position has been locked (IPOR Index Vale +/- spread)
        uint256 fixedInterestRate;

    }

    struct IporDerivativeFee {
        //@notice amount
        uint256 liquidationDepositAmount;
        //@notice amount calculated based on deposit amount
        uint256 openingAmount;
        uint256 iporPublicationAmount;
        uint256 spreadPercentage;

    }

    //@notice IPOR Derivative
    struct IporDerivative {

        //@notice unique ID of this derivative
        uint256 id;

        DerivativeState state;

        //@notice Buyer of this derivative
        address buyer;

        //@notice the name of the asset to which the derivative relates
        string asset;

        //@notice derivative direction: pay fixed and receive a floating or receive fixed and pay a floating
        uint8 direction;

        //@notice Derivative deposit amount
        uint256 depositAmount;

        IporDerivativeFee fee;

        uint256 leverage;

        //@notice Notional Principal Amount
        uint256 notionalAmount;

        //@notice Starting time of this Derivative
        uint256 startingTimestamp;

        //@notice Endind time of this Derivative
        uint256 endingTimestamp;

        IporDerivativeIndicator indicator;

    }
}