// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.9;

import "./MockCase5Milton.sol";

contract MockCase5MiltonUsdc is MockCase5Milton {
    function _getDecimals() internal pure virtual override returns (uint256) {
        return 6;
    }
}
