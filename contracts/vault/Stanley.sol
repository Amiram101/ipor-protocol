// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "../security/IporOwnableUpgradeable.sol";
import "./interfaces/IPOR/IStrategy.sol";
import "../interfaces/IStanley.sol";
import "../interfaces/IStanleyAdministration.sol";
import "./interfaces/IIvToken.sol";
import "../IporErrors.sol";
import "../libraries/IporMath.sol";
import "hardhat/console.sol";

abstract contract Stanley is
    UUPSUpgradeable,
    PausableUpgradeable,
    IporOwnableUpgradeable,
    IStanley,
    IStanleyAdministration
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address internal _asset;
    IIvToken internal _ivToken;

    address internal _milton;
    address internal _aaveStrategy;
    address internal _aaveShareToken;
    address internal _compoundStrategy;
    address internal _compoundShareToken;

    /**
     * @dev Deploy IPORVault.
     * @notice Deploy IPORVault.
     * @param asset underlying token like DAI, USDT etc.
     */
    function initialize(
        address asset,
        address ivToken,
        address strategyAave,
        address strategyCompound
    ) public initializer {
        __Ownable_init();
        require(asset != address(0), IporErrors.WRONG_ADDRESS);
        require(ivToken != address(0), IporErrors.WRONG_ADDRESS);

        _asset = asset;
        require(_getDecimals() == ERC20Upgradeable(asset).decimals(), IporErrors.WRONG_DECIMALS);
        _ivToken = IIvToken(ivToken);

        _setAaveStrategy(strategyAave);
        _setCompoundStrategy(strategyCompound);
    }

    modifier onlyMilton() {
        require(msg.sender == _milton, IporErrors.CALLER_NOT_MILTON);
        _;
    }

	function _getDecimals() internal pure virtual returns (uint256);

    function totalBalance(address who) external view override returns (uint256) {
        return _totalBalance(who);
    }

    /**
     * @dev to deposit asset in higher apy strategy.
     * @notice only owner can deposit.
     * @param amount underlying token amount represented in 18 decimals
     */
    //  TODO: ADD tests for amount = 0
    function deposit(uint256 amount) external override onlyMilton returns (uint256) {
        require(amount != 0, IporErrors.UINT_SHOULD_BE_GRATER_THEN_ZERO);

        (IStrategy strategyMaxApy, , ) = _getMaxApyStrategy();

        (
            uint256 exchangeRate,
            uint256 assetBalanceAave,
            uint256 assetBalanceCompound
        ) = _calcExchangeRate();

        uint256 ivTokenValue = IporMath.division(amount * Constants.D18, exchangeRate);

        _depositToStrategy(strategyMaxApy, amount);

        _ivToken.mint(msg.sender, ivTokenValue);

        emit Deposit(
            block.timestamp,
            msg.sender,
            address(strategyMaxApy),
            exchangeRate,
            amount,
            ivTokenValue
        );

        return assetBalanceAave + assetBalanceCompound + amount;
    }

    /**
     * @dev to withdraw asset from current strategy.
     * @notice only owner can withdraw.
     * @param amount underlying token amount represented in 18 decimals
            Shares means aTokens, cTokens
    */
    function withdraw(uint256 amount)
        external
        override
        onlyMilton
        returns (uint256 withdrawnValue, uint256 balance)
    {
        require(amount != 0, IporErrors.UINT_SHOULD_BE_GRATER_THEN_ZERO);

        IIvToken ivToken = _ivToken;

        (
            IStrategy strategyMaxApy,
            IStrategy strategyAave,
            IStrategy strategyCompound
        ) = _getMaxApyStrategy();

        (
            uint256 exchangeRate,
            uint256 assetBalanceAave,
            uint256 assetBalanceCompound
        ) = _calcExchangeRate();

        uint256 ivTokenValue = IporMath.division(amount * Constants.D18, exchangeRate);
        uint256 senderIvTokens = ivToken.balanceOf(msg.sender);

        if (senderIvTokens < ivTokenValue) {
            amount = IporMath.divisionWithoutRound(senderIvTokens * exchangeRate, Constants.D18);
            ivTokenValue = senderIvTokens;
        }

        if (address(strategyMaxApy) == _compoundStrategy && amount <= assetBalanceAave) {
            ivToken.burn(msg.sender, ivTokenValue);
            _withdrawFromStrategy(address(strategyAave), amount, ivTokenValue, exchangeRate, true);

            withdrawnValue = amount;
            balance = assetBalanceAave + assetBalanceCompound - withdrawnValue;

            return (withdrawnValue, balance);
        } else if (amount <= assetBalanceCompound) {
            ivToken.burn(msg.sender, ivTokenValue);
            _withdrawFromStrategy(
                address(strategyCompound),
                amount,
                ivTokenValue,
                exchangeRate,
                true
            );

            withdrawnValue = amount;
            balance = assetBalanceAave + assetBalanceCompound - withdrawnValue;

            return (withdrawnValue, balance);
        }

        if (address(strategyMaxApy) == _aaveStrategy && amount <= assetBalanceCompound) {
            ivToken.burn(msg.sender, ivTokenValue);
            _withdrawFromStrategy(
                address(strategyCompound),
                amount,
                ivTokenValue,
                exchangeRate,
                true
            );

            withdrawnValue = amount;
            balance = assetBalanceAave + assetBalanceCompound - withdrawnValue;

            return (withdrawnValue, balance);
        } else if (amount <= assetBalanceAave) {
            ivToken.burn(msg.sender, ivTokenValue);
            _withdrawFromStrategy(address(strategyAave), amount, ivTokenValue, exchangeRate, true);

            withdrawnValue = amount;
            balance = assetBalanceAave + assetBalanceCompound - withdrawnValue;

            return (withdrawnValue, balance);
        }

        if (assetBalanceAave < assetBalanceCompound) {
            uint256 ivTokenValuePart = IporMath.division(
                assetBalanceCompound * Constants.D18,
                exchangeRate
            );

            _ivToken.burn(msg.sender, ivTokenValuePart);
            _withdrawFromStrategy(
                address(strategyCompound),
                assetBalanceCompound,
                ivTokenValuePart,
                exchangeRate,
                true
            );

            withdrawnValue = assetBalanceCompound;
        } else {
            // TODO: Add tests for DAI(18 decimals) and for USDT (6 decimals)
            uint256 ivTokenValuePart = IporMath.division(
                assetBalanceAave * Constants.D18,
                exchangeRate
            );
            ivToken.burn(msg.sender, ivTokenValuePart);
            _withdrawFromStrategy(
                address(strategyAave),
                assetBalanceAave,
                ivTokenValuePart,
                exchangeRate,
                true
            );
            withdrawnValue = assetBalanceAave;
        }

        balance = assetBalanceAave + assetBalanceCompound - withdrawnValue;

        return (withdrawnValue, balance);
    }

    function withdrawAll()
        external
        override
        onlyMilton
        returns (uint256 withdrawnValue, uint256 vaultBalance)
    {
        IStrategy strategyAave = IStrategy(_aaveStrategy);

        (uint256 exchangeRate, , ) = _calcExchangeRate();

        uint256 assetBalanceAave = strategyAave.balanceOf();
        uint256 ivTokenValueAave = IporMath.division(
            assetBalanceAave * Constants.D18,
            exchangeRate
        );

        _withdrawFromStrategy(
            address(strategyAave),
            assetBalanceAave,
            ivTokenValueAave,
            exchangeRate,
            false
        );

        IStrategy strategyCompound = IStrategy(_compoundStrategy);

        uint256 assetBalanceCompound = strategyCompound.balanceOf();
        uint256 ivTokenValueCompound = IporMath.division(
            assetBalanceCompound * Constants.D18,
            exchangeRate
        );

        _withdrawFromStrategy(
            address(strategyCompound),
            assetBalanceCompound,
            ivTokenValueCompound,
            exchangeRate,
            false
        );

        uint256 balance = ERC20Upgradeable(_asset).balanceOf(address(this));
        uint256 wadBalance;

        if (balance != 0) {
            IERC20Upgradeable(_asset).safeTransfer(msg.sender, balance);
            wadBalance = IporMath.convertToWad(balance, _getDecimals());
        }

        withdrawnValue = assetBalanceAave + assetBalanceCompound + wadBalance;
        vaultBalance = 0;
    }

    //TODO:!!! add test for it where ivTokens, shareTokens and balances are checked before and after execution
    function migrateAssetToStrategyWithMaxApy() external onlyOwner {
        (
            IStrategy strategyMaxApy,
            IStrategy strategyAave,
            IStrategy strategyCompound
        ) = _getMaxApyStrategy();

        uint256 decimals = _getDecimals();
        address from;

        if (address(strategyMaxApy) == address(strategyAave)) {
            from = address(strategyCompound);
            uint256 shares = IERC20Upgradeable(_compoundShareToken).balanceOf(from);
            require(shares > 0, IporErrors.UINT_SHOULD_BE_GRATER_THEN_ZERO);
            strategyCompound.withdraw(IporMath.convertToWad(shares, decimals));
        } else {
            from = address(strategyAave);
            uint256 shares = IERC20Upgradeable(_aaveShareToken).balanceOf(from);
            require(shares > 0, IporErrors.UINT_SHOULD_BE_GRATER_THEN_ZERO);
            strategyAave.withdraw(IporMath.convertToWad(shares, decimals));
        }

        uint256 amount = ERC20Upgradeable(_asset).balanceOf(address(this));
        uint256 wadAmount = IporMath.convertToWad(amount, decimals);
        _depositToStrategy(strategyMaxApy, wadAmount);

        emit MigrateAsset(from, address(strategyMaxApy), wadAmount);
    }

    function setAaveStrategy(address strategyAddress) external override onlyOwner {
        _setAaveStrategy(strategyAddress);
    }

    function setCompoundStrategy(address strategy) external override onlyOwner {
        _setCompoundStrategy(strategy);
    }

    function setMilton(address milton) external override onlyOwner {
        _milton = milton;
    }

    // Find highest apy strategy to deposit underlying asset
    function _getMaxApyStrategy()
        internal
        view
        returns (
            IStrategy strategyMaxApy,
            IStrategy strategyAave,
            IStrategy strategyCompound
        )
    {
        strategyAave = IStrategy(_aaveStrategy);
        strategyCompound = IStrategy(_compoundStrategy);

        if (strategyAave.getApr() < strategyCompound.getApr()) {
            strategyMaxApy = strategyCompound;
        } else {
            strategyMaxApy = strategyAave;
        }
    }

    function _totalBalance(address who) internal view returns (uint256) {
        (uint256 exchangeRate, , ) = _calcExchangeRate();
        return IporMath.division(_ivToken.balanceOf(who) * exchangeRate, Constants.D18);
    }

    /**
     * @dev to migrate all asset from current strategy to another higher apy strategy.
     * @notice only owner can migrate.
     */
    function _setCompoundStrategy(address newStrategy) internal {
        require(newStrategy != address(0), IporErrors.WRONG_ADDRESS);

        IERC20Upgradeable asset = IERC20Upgradeable(_asset);

        IStrategy strategy = IStrategy(newStrategy);
        IERC20Upgradeable shareToken = IERC20Upgradeable(_compoundShareToken);

        require(
            strategy.getAsset() == address(asset),
            IporErrors.UNDERLYINGTOKEN_IS_NOT_COMPATIBLE
        );

        if (_compoundStrategy != address(0)) {
            asset.safeApprove(_compoundStrategy, 0);
            shareToken.safeApprove(_compoundStrategy, 0);
        }

        _compoundStrategy = newStrategy;
        _compoundShareToken = IStrategy(newStrategy).getShareToken();

        IERC20Upgradeable newShareToken = IERC20Upgradeable(_compoundShareToken);

        asset.safeApprove(newStrategy, 0);
        asset.safeApprove(newStrategy, type(uint256).max);

        newShareToken.safeApprove(newStrategy, 0);
        newShareToken.safeApprove(newStrategy, type(uint256).max);

        emit SetStrategy(newStrategy, _compoundShareToken);
    }

    function _setAaveStrategy(address newStrategy) internal {
        require(newStrategy != address(0), IporErrors.WRONG_ADDRESS);

        IERC20Upgradeable asset = ERC20Upgradeable(_asset);

        IStrategy strategy = IStrategy(newStrategy);

        require(
            strategy.getAsset() == address(asset),
            IporErrors.UNDERLYINGTOKEN_IS_NOT_COMPATIBLE
        );

        if (_aaveStrategy != address(0)) {
            asset.safeApprove(_aaveStrategy, 0);
            IERC20Upgradeable(_aaveShareToken).safeApprove(_aaveStrategy, 0);
        }

        _aaveShareToken = strategy.getShareToken();
        _aaveStrategy = newStrategy;

        IERC20Upgradeable newShareToken = IERC20Upgradeable(_aaveShareToken);

        asset.safeApprove(newStrategy, 0);
        asset.safeApprove(newStrategy, type(uint256).max);

        newShareToken.safeApprove(newStrategy, 0);
        newShareToken.safeApprove(newStrategy, type(uint256).max);

        emit SetStrategy(newStrategy, _aaveShareToken);
    }

    /**
     * @dev to withdraw asset from current strategy.
     * @notice internal method.
     * @param strategyAddress strategy from amount to withdraw
     * @param amount is interest bearing token like aDAI, cDAI etc.
     */
    function _withdrawFromStrategy(
        address strategyAddress,
        uint256 amount,
        uint256 ivTokenValue,
        uint256 exchangeRate,
        bool transfer
    ) internal {
        if (amount != 0) {
            IStrategy(strategyAddress).withdraw(amount);

            IERC20Upgradeable asset = IERC20Upgradeable(_asset);

            uint256 balance = asset.balanceOf(address(this));

            if (transfer) {
                asset.safeTransfer(msg.sender, balance);
            }
            emit Withdraw(
                block.timestamp,
                strategyAddress,
                msg.sender,
                exchangeRate,
                amount,
                ivTokenValue
            );
        }
    }

    /**  Internal Methods */
    /**
     * @dev to deposit asset in current strategy.
     * @notice internal method.
     * @param strategyAddress strategy from amount to deposit
     * @param wadAmount _amount is _asset token like DAI.
     */
    function _depositToStrategy(IStrategy strategyAddress, uint256 wadAmount) internal {
        uint256 amount = IporMath.convertWadToAssetDecimals(wadAmount, _getDecimals());
        _depositToStrategy(strategyAddress, wadAmount, amount);
    }

    function _depositToStrategy(
        IStrategy strategyAddress,
        uint256 wadAmount,
        uint256 amount
    ) internal {
        IERC20Upgradeable(_asset).safeTransferFrom(msg.sender, address(this), amount);
        strategyAddress.deposit(wadAmount);
    }

    function _calcExchangeRate()
        internal
        view
        returns (
            uint256 exchangeRate,
            uint256 assetBalanceAave,
            uint256 assetBalanceCompound
        )
    {
        assetBalanceAave = IStrategy(_aaveStrategy).balanceOf();
        assetBalanceCompound = IStrategy(_compoundStrategy).balanceOf();

        uint256 totalAssetBalance = assetBalanceAave + assetBalanceCompound;

        uint256 ivTokenBalance = _ivToken.totalSupply();

        if (totalAssetBalance == 0 || ivTokenBalance == 0) {
            exchangeRate = Constants.D18;
        } else {
            exchangeRate = IporMath.division(totalAssetBalance * Constants.D18, ivTokenBalance);
        }
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
