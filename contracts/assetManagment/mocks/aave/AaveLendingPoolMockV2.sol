pragma solidity 0.8.9;
pragma experimental ABIEncoderV2;

// interfaces
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/aave/AaveLendingPoolV2.sol";
import "../../interfaces/aave/DataTypes.sol";
import "../../interfaces/aave/AToken.sol";
import "./ADAIMock.sol";

contract AaveLendingPoolMockV2 is AaveLendingPoolV2 {
    address private _dai;
    address private _aDai;
    address private _stableDebtTokenAddress;
    address private _variableDebtTokenAddress;
    address private _interestRateStrategyAddress;
    uint128 private _currentLiquidityRate;

    constructor(address dai, address aDai) {
        _dai = dai;
        _aDai = aDai;
    }

    function deposit(
        address,
        uint256 amount,
        address recipient,
        uint16
    ) external override {
        IERC20(_aDai).transfer(recipient, amount);
    }

    function setStableDebtTokenAddress(address a) external {
        _stableDebtTokenAddress = a;
    }

    function setVariableDebtTokenAddress(address a) external {
        _variableDebtTokenAddress = a;
    }

    function setInterestRateStrategyAddress(address a) external {
        _interestRateStrategyAddress = a;
    }

    function setCurrentLiquidityRate(uint128 v) external {
        _currentLiquidityRate = v;
    }

    function getReserveData(address reserve)
        external
        view
        override
        returns (DataTypes.ReserveData memory)
    {
        DataTypes.ReserveData memory d;
        d.stableDebtTokenAddress = _stableDebtTokenAddress;
        d.variableDebtTokenAddress = _variableDebtTokenAddress;
        d.interestRateStrategyAddress = _interestRateStrategyAddress;
        d.currentLiquidityRate = _currentLiquidityRate;
        return d;
    }

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external override {
        AToken(_aDai).burn(msg.sender, to, amount, 0);
    }
}
