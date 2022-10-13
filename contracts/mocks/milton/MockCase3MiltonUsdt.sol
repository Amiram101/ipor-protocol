// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "./MockCase3Milton.sol";

contract MockCase3MiltonUsdt is MockCase3Milton {
    function _getDecimals() internal pure virtual override returns (uint256) {
        return 6;
    }
}
