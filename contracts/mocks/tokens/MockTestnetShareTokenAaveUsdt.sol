// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./MockTestnetToken.sol";

//solhint-disable no-empty-blocks
contract MockTestnetShareTokenAaveUsdt is MockTestnetToken {
    constructor(uint256 initialSupply)
        MockTestnetToken("Mocked Share aUSDT", "aUSDT", initialSupply, 6)
    {}
}
